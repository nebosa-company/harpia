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
        let _ = (status, body);
        todo!("build a text response")
    }
}

/// Read and parse ONE request from `stream`.
pub fn read_request(stream: &mut impl Read) -> Result<Request, String> {
    let _ = stream;
    todo!("parse the request")
}

/// Serialize `resp` to `stream` (status line, headers, auto headers, body).
pub fn write_response(stream: &mut impl Write, resp: &Response) -> std::io::Result<()> {
    let _ = (stream, resp);
    todo!("serialize the response")
}

type Handler = Box<dyn Fn(&Request) -> Response + Send + Sync + 'static>;

/// Method + pattern router.
pub struct Router {
    _todo: std::marker::PhantomData<Handler>,
}

impl Router {
    /// An empty router.
    pub fn new() -> Router {
        todo!("create the router")
    }

    /// Register `handler` for `method` + `pattern` (segments; `:name`
    /// captures). Registration order is match order.
    pub fn route<H>(&mut self, method: &str, pattern: &str, handler: H)
    where
        H: Fn(&Request) -> Response + Send + Sync + 'static,
    {
        let _ = (method, pattern, handler);
        todo!("register the route")
    }

    /// Route `req`: fill params and call the handler, or produce the
    /// 405/404 fallbacks.
    pub fn handle(&self, req: &mut Request) -> Response {
        let _ = req;
        todo!("dispatch the request")
    }

    /// Accept loop: one request per connection, forever.
    pub fn serve(self, listener: TcpListener) -> std::io::Result<()> {
        let _ = listener;
        todo!("serve connections")
    }
}

impl Default for Router {
    fn default() -> Self {
        Router::new()
    }
}
