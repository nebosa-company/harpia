//! A tiny HTTP/1.1 server library: request parsing, pattern routing with
//! `:param` captures, and a one-request-per-connection accept loop over
//! std::net::TcpListener.

use std::collections::HashMap;
use std::io::{Read, Write};
use std::net::TcpListener;

/// One parsed HTTP request.
#[derive(Debug)]
pub struct Request {
    /// e.g. "GET" (case-sensitive).
    pub method: String,
    /// Target path without the query string, undecoded.
    pub path: String,
    /// Query-string pairs (last duplicate wins).
    pub query: HashMap<String, String>,
    /// Path-pattern captures, filled by the router.
    pub params: HashMap<String, String>,
    /// Header names lowercased, values trimmed.
    pub headers: HashMap<String, String>,
    /// Raw body (empty without content-length).
    pub body: Vec<u8>,
}

/// One HTTP response.
#[derive(Debug)]
pub struct Response {
    pub status: u16,
    /// Written in order, before the automatic content-length / connection.
    pub headers: Vec<(String, String)>,
    pub body: Vec<u8>,
}

impl Response {
    /// A text/plain response.
    pub fn text(status: u16, body: &str) -> Response {
        Response {
            status,
            headers: vec![("content-type".to_string(), "text/plain".to_string())],
            body: body.as_bytes().to_vec(),
        }
    }
}

/// Read bytes up to and including '\n'; strip "\r\n" or "\n".
fn read_line(stream: &mut impl Read) -> Result<String, String> {
    let mut bytes = Vec::new();
    let mut one = [0u8; 1];
    loop {
        match stream.read(&mut one) {
            Ok(0) => break,
            Ok(_) => {
                if one[0] == b'\n' {
                    break;
                }
                bytes.push(one[0]);
            }
            Err(e) => return Err(format!("read error: {e}")),
        }
    }
    if bytes.last() == Some(&b'\r') {
        bytes.pop();
    }
    String::from_utf8(bytes).map_err(|_| "non-utf8 header data".to_string())
}

fn parse_query(raw: &str) -> HashMap<String, String> {
    let mut out = HashMap::new();
    for pair in raw.split('&') {
        if pair.is_empty() {
            continue;
        }
        let (k, v) = match pair.split_once('=') {
            Some((k, v)) => (k, v),
            None => (pair, ""),
        };
        out.insert(k.to_string(), v.to_string());
    }
    out
}

/// Read and parse ONE request from `stream`.
pub fn read_request(stream: &mut impl Read) -> Result<Request, String> {
    let request_line = read_line(stream)?;
    let mut parts = request_line.split(' ');
    let (Some(method), Some(target), Some(version), None) =
        (parts.next(), parts.next(), parts.next(), parts.next())
    else {
        return Err(format!("malformed request line `{request_line}`"));
    };
    if version != "HTTP/1.1" {
        return Err(format!("unsupported version `{version}`"));
    }
    if method.is_empty() || target.is_empty() {
        return Err("empty method or target".to_string());
    }
    let (path, query) = match target.split_once('?') {
        Some((p, q)) => (p.to_string(), parse_query(q)),
        None => (target.to_string(), HashMap::new()),
    };
    let mut headers = HashMap::new();
    loop {
        let line = read_line(stream)?;
        if line.is_empty() {
            break;
        }
        let Some((name, value)) = line.split_once(':') else {
            return Err(format!("malformed header `{line}`"));
        };
        headers.insert(name.trim().to_ascii_lowercase(), value.trim().to_string());
    }
    let mut body = Vec::new();
    if let Some(raw_len) = headers.get("content-length") {
        let len: usize = raw_len
            .parse()
            .map_err(|_| format!("bad content-length `{raw_len}`"))?;
        body.resize(len, 0);
        stream
            .read_exact(&mut body)
            .map_err(|e| format!("short body: {e}"))?;
    }
    Ok(Request {
        method: method.to_string(),
        path,
        query,
        params: HashMap::new(),
        headers,
        body,
    })
}

fn reason(status: u16) -> &'static str {
    match status {
        200 => "OK",
        201 => "Created",
        204 => "No Content",
        400 => "Bad Request",
        403 => "Forbidden",
        404 => "Not Found",
        405 => "Method Not Allowed",
        500 => "Internal Server Error",
        _ => "Unknown",
    }
}

/// Serialize `resp` to `stream` (status line, headers, auto headers, body).
pub fn write_response(stream: &mut impl Write, resp: &Response) -> std::io::Result<()> {
    let mut head = format!("HTTP/1.1 {} {}\r\n", resp.status, reason(resp.status));
    for (name, value) in &resp.headers {
        head.push_str(&format!("{name}: {value}\r\n"));
    }
    head.push_str(&format!("content-length: {}\r\n", resp.body.len()));
    head.push_str("connection: close\r\n\r\n");
    stream.write_all(head.as_bytes())?;
    stream.write_all(&resp.body)?;
    stream.flush()
}

type Handler = Box<dyn Fn(&Request) -> Response + Send + Sync + 'static>;

struct Route {
    method: String,
    segments: Vec<String>,
    handler: Handler,
}

fn match_pattern(segments: &[String], path: &str) -> Option<HashMap<String, String>> {
    let path_segs: Vec<&str> = path.split('/').collect();
    if path_segs.len() != segments.len() {
        return None;
    }
    let mut params = HashMap::new();
    for (pat, seg) in segments.iter().zip(&path_segs) {
        if let Some(name) = pat.strip_prefix(':') {
            params.insert(name.to_string(), (*seg).to_string());
        } else if pat != seg {
            return None;
        }
    }
    Some(params)
}

/// Method + pattern router.
pub struct Router {
    routes: Vec<Route>,
}

impl Router {
    /// An empty router.
    pub fn new() -> Router {
        Router { routes: Vec::new() }
    }

    /// Register `handler` for `method` + `pattern`.
    pub fn route<H>(&mut self, method: &str, pattern: &str, handler: H)
    where
        H: Fn(&Request) -> Response + Send + Sync + 'static,
    {
        self.routes.push(Route {
            method: method.to_string(),
            segments: pattern.split('/').map(|s| s.to_string()).collect(),
            handler: Box::new(handler),
        });
    }

    /// Route `req`: fill params and call the handler, or 405/404.
    pub fn handle(&self, req: &mut Request) -> Response {
        let mut other_methods: Vec<String> = Vec::new();
        for route in &self.routes {
            if let Some(params) = match_pattern(&route.segments, &req.path) {
                if route.method == req.method {
                    req.params = params;
                    return (route.handler)(req);
                }
                if !other_methods.contains(&route.method) {
                    other_methods.push(route.method.clone());
                }
            }
        }
        if !other_methods.is_empty() {
            other_methods.sort();
            let mut resp = Response::text(405, "method not allowed");
            resp.headers
                .push(("allow".to_string(), other_methods.join(", ")));
            return resp;
        }
        Response::text(404, "not found")
    }

    /// Accept loop: one request per connection, forever.
    pub fn serve(self, listener: TcpListener) -> std::io::Result<()> {
        for stream in listener.incoming() {
            let Ok(mut stream) = stream else { continue };
            let response = match read_request(&mut stream) {
                Ok(mut req) => self.handle(&mut req),
                Err(_) => Response::text(400, "bad request"),
            };
            let _ = write_response(&mut stream, &response);
            // stream drops here: connection closed.
        }
        Ok(())
    }
}

impl Default for Router {
    fn default() -> Self {
        Router::new()
    }
}
