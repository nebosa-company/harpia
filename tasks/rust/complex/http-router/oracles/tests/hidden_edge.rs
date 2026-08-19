use http_router::{Response, Router};
use std::collections::HashMap;
use std::io::{Read, Write};
use std::net::{SocketAddr, TcpListener, TcpStream};
use std::time::Duration;

fn start(router: Router) -> SocketAddr {
    let listener = TcpListener::bind("127.0.0.1:0").expect("bind loopback");
    let addr = listener.local_addr().unwrap();
    std::thread::spawn(move || {
        let _ = router.serve(listener);
    });
    addr
}

fn roundtrip(addr: SocketAddr, raw: &[u8]) -> (String, HashMap<String, String>, Vec<u8>) {
    let mut stream = TcpStream::connect(addr).expect("connect");
    stream.set_read_timeout(Some(Duration::from_secs(10))).unwrap();
    stream.write_all(raw).unwrap();
    let mut buf = Vec::new();
    let mut chunk = [0u8; 4096];
    loop {
        match stream.read(&mut chunk) {
            Ok(0) => break,
            Ok(n) => buf.extend_from_slice(&chunk[..n]),
            // A reset after the response arrived still counts as a close.
            Err(e) if !buf.is_empty() => {
                let _ = e;
                break;
            }
            Err(e) => panic!("no response before connection error: {e}"),
        }
    }
    let split = buf
        .windows(4)
        .position(|w| w == b"\r\n\r\n")
        .expect("header/body separator");
    let head = String::from_utf8(buf[..split].to_vec()).unwrap();
    let body = buf[split + 4..].to_vec();
    let mut lines = head.split("\r\n");
    let status_line = lines.next().unwrap().to_string();
    let mut headers = HashMap::new();
    for line in lines {
        let (n, v) = line.split_once(':').expect("header colon");
        headers.insert(n.trim().to_ascii_lowercase(), v.trim().to_string());
    }
    (status_line, headers, body)
}

fn demo_router() -> Router {
    let mut router = Router::new();
    router.route("GET", "/hello/:name", |r| {
        Response::text(200, &format!("hello {}", r.params["name"]))
    });
    router.route("POST", "/sum", |r| {
        let text = String::from_utf8_lossy(&r.body);
        let total: i64 = text.split(',').filter_map(|p| p.trim().parse::<i64>().ok()).sum();
        Response::text(201, &total.to_string())
    });
    router
}

#[test]
fn end_to_end_get_with_params() {
    let addr = start(demo_router());
    let (status, headers, body) =
        roundtrip(addr, b"GET /hello/world HTTP/1.1\r\nhost: t\r\n\r\n");
    assert_eq!(status, "HTTP/1.1 200 OK");
    assert_eq!(body, b"hello world");
    assert_eq!(headers.get("content-type").map(|s| s.as_str()), Some("text/plain"));
    assert_eq!(headers.get("content-length").map(|s| s.as_str()), Some("11"));
    assert_eq!(headers.get("connection").map(|s| s.as_str()), Some("close"));
}

#[test]
fn end_to_end_post_with_body() {
    let addr = start(demo_router());
    let (status, _, body) = roundtrip(
        addr,
        b"POST /sum HTTP/1.1\r\ncontent-length: 8\r\n\r\n2,3,10,5",
    );
    assert_eq!(status, "HTTP/1.1 201 Created");
    assert_eq!(body, b"20");
}

#[test]
fn end_to_end_404() {
    let addr = start(demo_router());
    let (status, _, body) = roundtrip(addr, b"GET /nope HTTP/1.1\r\n\r\n");
    assert_eq!(status, "HTTP/1.1 404 Not Found");
    assert_eq!(body, b"not found");
}

#[test]
fn end_to_end_405_with_allow() {
    let addr = start(demo_router());
    let (status, headers, _) = roundtrip(addr, b"DELETE /sum HTTP/1.1\r\n\r\n");
    assert_eq!(status, "HTTP/1.1 405 Method Not Allowed");
    assert_eq!(headers.get("allow").map(|s| s.as_str()), Some("POST"));
}

#[test]
fn malformed_request_gets_400() {
    let addr = start(demo_router());
    let (status, _, body) = roundtrip(addr, b"TOTAL GARBAGE\r\n");
    assert_eq!(status, "HTTP/1.1 400 Bad Request");
    assert_eq!(body, b"bad request");
}

#[test]
fn server_survives_bad_then_good_connections() {
    let addr = start(demo_router());
    let (status, _, _) = roundtrip(addr, b"BROKEN\r\n");
    assert_eq!(status, "HTTP/1.1 400 Bad Request");
    // The accept loop must still be alive:
    for i in 0..3 {
        let (status, _, body) =
            roundtrip(addr, b"GET /hello/again HTTP/1.1\r\n\r\n");
        assert_eq!(status, "HTTP/1.1 200 OK", "request {i} after a bad one");
        assert_eq!(body, b"hello again");
    }
}

#[test]
fn query_strings_over_the_wire() {
    let mut router = Router::new();
    router.route("GET", "/q", |r| {
        Response::text(200, r.query.get("term").map(|s| s.as_str()).unwrap_or("-"))
    });
    let addr = start(router);
    let (_, _, body) = roundtrip(addr, b"GET /q?term=xyzzy&n=1 HTTP/1.1\r\n\r\n");
    assert_eq!(body, b"xyzzy");
}
