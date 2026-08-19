use http_router::{read_request, write_response, Request, Response, Router};
use std::collections::HashMap;
use std::io::Cursor;

fn parse(raw: &str) -> Result<Request, String> {
    read_request(&mut Cursor::new(raw.as_bytes().to_vec()))
}

fn req(method: &str, path: &str) -> Request {
    Request {
        method: method.to_string(),
        path: path.to_string(),
        query: HashMap::new(),
        params: HashMap::new(),
        headers: HashMap::new(),
        body: Vec::new(),
    }
}

#[test]
fn parses_a_simple_get() {
    let r = parse("GET /health HTTP/1.1\r\nHost: x\r\n\r\n").unwrap();
    assert_eq!(r.method, "GET");
    assert_eq!(r.path, "/health");
    assert!(r.query.is_empty());
    assert!(r.body.is_empty());
    assert_eq!(r.headers.get("host").map(|s| s.as_str()), Some("x"));
}

#[test]
fn parses_query_strings() {
    let r = parse("GET /s?q=rust&limit=10&flag&q=final HTTP/1.1\r\n\r\n").unwrap();
    assert_eq!(r.path, "/s");
    assert_eq!(r.query.get("q").map(|s| s.as_str()), Some("final"), "last dup wins");
    assert_eq!(r.query.get("limit").map(|s| s.as_str()), Some("10"));
    assert_eq!(r.query.get("flag").map(|s| s.as_str()), Some(""));
    let r = parse("GET /s?a=1&&b=2 HTTP/1.1\r\n\r\n").unwrap();
    assert_eq!(r.query.len(), 2);
}

#[test]
fn headers_are_lowercased_and_trimmed() {
    let r = parse("GET / HTTP/1.1\r\nX-Custom-Header:  padded value \r\nACCEPT: */*\r\n\r\n")
        .unwrap();
    assert_eq!(r.headers.get("x-custom-header").map(|s| s.as_str()), Some("padded value"));
    assert_eq!(r.headers.get("accept").map(|s| s.as_str()), Some("*/*"));
}

#[test]
fn reads_body_by_content_length() {
    let r = parse("POST /u HTTP/1.1\r\nContent-Length: 11\r\n\r\nhello world").unwrap();
    assert_eq!(r.body, b"hello world");
    let r = parse("POST /u HTTP/1.1\r\nContent-Length: 4\r\n\r\nabcdEXTRA").unwrap();
    assert_eq!(r.body, b"abcd", "read exactly content-length bytes");
}

#[test]
fn tolerates_bare_lf() {
    let r = parse("GET /x HTTP/1.1\nHost: y\n\n").unwrap();
    assert_eq!(r.path, "/x");
    assert_eq!(r.headers.get("host").map(|s| s.as_str()), Some("y"));
}

#[test]
fn malformed_requests_error() {
    assert!(parse("GET /x HTTP/1.0\r\n\r\n").is_err(), "wrong version");
    assert!(parse("GET /x\r\n\r\n").is_err(), "missing version");
    assert!(parse("GET /x HTTP/1.1 extra\r\n\r\n").is_err(), "four parts");
    assert!(parse("GET /x HTTP/1.1\r\nno-colon-here\r\n\r\n").is_err());
    assert!(parse("POST /u HTTP/1.1\r\nContent-Length: nan\r\n\r\n").is_err());
    assert!(parse("").is_err());
}

#[test]
fn write_response_is_exact() {
    let mut out = Vec::new();
    let mut resp = Response::text(200, "hi");
    resp.headers.push(("x-extra".to_string(), "1".to_string()));
    write_response(&mut out, &resp).unwrap();
    let text = String::from_utf8(out).unwrap();
    assert_eq!(
        text,
        "HTTP/1.1 200 OK\r\ncontent-type: text/plain\r\nx-extra: 1\r\ncontent-length: 2\r\nconnection: close\r\n\r\nhi"
    );
}

#[test]
fn reason_phrases() {
    for (status, reason) in [
        (201, "Created"),
        (204, "No Content"),
        (400, "Bad Request"),
        (403, "Forbidden"),
        (404, "Not Found"),
        (405, "Method Not Allowed"),
        (500, "Internal Server Error"),
        (299, "Unknown"),
    ] {
        let mut out = Vec::new();
        write_response(&mut out, &Response { status, headers: vec![], body: vec![] }).unwrap();
        let text = String::from_utf8(out).unwrap();
        assert!(
            text.starts_with(&format!("HTTP/1.1 {status} {reason}\r\n")),
            "{status}: {text:?}"
        );
    }
}

#[test]
fn routing_literals_params_and_order() {
    let mut router = Router::new();
    router.route("GET", "/users/all", |_| Response::text(200, "all"));
    router.route("GET", "/users/:id", |r| {
        Response::text(200, &format!("user={}", r.params["id"]))
    });
    router.route("GET", "/a/:x/b/:y", |r| {
        Response::text(200, &format!("{}-{}", r.params["x"], r.params["y"]))
    });

    let mut r = req("GET", "/users/all");
    assert_eq!(router.handle(&mut r).body, b"all", "first registered wins");
    let mut r = req("GET", "/users/42");
    assert_eq!(router.handle(&mut r).body, b"user=42");
    let mut r = req("GET", "/a/1/b/2");
    assert_eq!(router.handle(&mut r).body, b"1-2");
    let mut r = req("GET", "/a/1/b");
    assert_eq!(router.handle(&mut r).status, 404, "segment count must match");
    let mut r = req("GET", "/users/42/extra");
    assert_eq!(router.handle(&mut r).status, 404);
}

#[test]
fn fallbacks_404_and_405() {
    let mut router = Router::new();
    router.route("GET", "/thing", |_| Response::text(200, "got"));
    router.route("POST", "/thing", |_| Response::text(201, "made"));
    router.route("DELETE", "/other/:id", |_| Response::text(204, ""));

    let mut r = req("PUT", "/thing");
    let resp = router.handle(&mut r);
    assert_eq!(resp.status, 405);
    assert_eq!(resp.body, b"method not allowed");
    let allow = resp
        .headers
        .iter()
        .find(|(n, _)| n == "allow")
        .map(|(_, v)| v.as_str());
    assert_eq!(allow, Some("GET, POST"));

    let mut r = req("GET", "/missing");
    let resp = router.handle(&mut r);
    assert_eq!(resp.status, 404);
    assert_eq!(resp.body, b"not found");
}

#[test]
fn handler_sees_query_and_body() {
    let mut router = Router::new();
    router.route("POST", "/echo/:tag", |r| {
        let q = r.query.get("mode").map(|s| s.as_str()).unwrap_or("none");
        let body = String::from_utf8_lossy(&r.body).to_string();
        Response::text(200, &format!("{}|{}|{}", r.params["tag"], q, body))
    });
    let mut r = parse("POST /echo/x?mode=loud HTTP/1.1\r\ncontent-length: 3\r\n\r\nyo!").unwrap();
    let resp = router.handle(&mut r);
    assert_eq!(resp.body, b"x|loud|yo!");
}
