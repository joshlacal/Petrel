use std::{
    future::{Future, ready},
    io::{Read, Write},
    net::{IpAddr, Ipv4Addr, TcpListener},
    sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    },
    thread,
    time::Duration,
};

use bytes::Bytes;
use flate2::{Compression, write::GzEncoder};
use http::Request;

use super::*;
use crate::identity::{DnsError, DnsResolver};

#[derive(Clone)]
struct FixedDns {
    answer: IpAddr,
    calls: Arc<AtomicUsize>,
}

impl DnsResolver for FixedDns {
    fn txt(&self, _name: &str) -> impl Future<Output = Result<Vec<String>, DnsError>> + Send {
        ready(Ok(Vec::new()))
    }

    fn lookup_ip(&self, _host: &str) -> impl Future<Output = Result<Vec<IpAddr>, DnsError>> + Send {
        self.calls.fetch_add(1, Ordering::Relaxed);
        ready(Ok(vec![self.answer]))
    }
}

fn options() -> SendOptions {
    SendOptions {
        timeout: Some(Duration::from_secs(2)),
        allow_loopback: true,
        ..SendOptions::default()
    }
}

fn request(url: &str) -> Request<Bytes> {
    Request::get(url).body(Bytes::new()).unwrap()
}

#[tokio::test]
async fn connector_refuses_every_dns_answer_outside_the_target_policy() {
    for (url, answer) in [
        ("https://public.example", "10.0.0.1"),
        ("http://localhost:9", "192.0.2.1"),
    ] {
        let calls = Arc::new(AtomicUsize::new(0));
        let transport = ReqwestTransport::with_dns(FixedDns {
            answer: answer.parse().unwrap(),
            calls: calls.clone(),
        })
        .unwrap();
        assert!(matches!(
            transport.send(request(url), &options()).await,
            Err(TransportError::PolicyViolation(_))
        ));
        assert_eq!(calls.load(Ordering::Relaxed), 1);
    }
}

#[tokio::test]
async fn native_transport_uses_approved_loopback_dns_once_and_returns_a_redirect_unchanged() {
    let address = IpAddr::V4(Ipv4Addr::LOCALHOST);
    let calls = Arc::new(AtomicUsize::new(0));
    let transport = ReqwestTransport::with_dns(FixedDns {
        answer: address,
        calls: calls.clone(),
    })
    .unwrap();

    let (port, fixture) = local_server(
        b"HTTP/1.1 302 Found\r\nLocation: https://unused.example\r\nContent-Length: 0\r\n\r\n"
            .to_vec(),
    );
    let uri = format!("http://localhost:{port}");
    assert!(matches!(
        transport.send(request(&uri), &SendOptions::default()).await,
        Err(TransportError::PolicyViolation(_))
    ));
    assert_eq!(calls.load(Ordering::Relaxed), 0);

    let result = transport.send(request(&uri), &options()).await.unwrap();
    assert_eq!(result.status(), 302);
    assert_eq!(result.headers()["location"], "https://unused.example");
    assert_eq!(calls.load(Ordering::Relaxed), 1);
    fixture.join().unwrap();
}

#[tokio::test]
async fn response_limits_apply_to_native_wire_bytes_and_expansion() {
    let transport = ReqwestTransport::with_dns(FixedDns {
        answer: IpAddr::V4(Ipv4Addr::LOCALHOST),
        calls: Arc::new(AtomicUsize::new(0)),
    })
    .unwrap();

    let mut opts = options();
    opts.max_response_bytes = Some(32);

    let (port, fixture) = local_server(b"HTTP/1.1 200 OK\r\nContent-Length: 99\r\n\r\n".to_vec());
    let result = transport
        .send(request(&format!("http://127.0.0.1:{port}")), &opts)
        .await;
    assert!(matches!(
        result,
        Err(TransportError::ResponseTooLarge { limit: 32 })
    ));
    fixture.join().unwrap();

    let (port, fixture) = local_server(b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n10\r\n1234567890123456\r\n20\r\n12345678901234561234567890123456\r\n0\r\n\r\n".to_vec());
    let result = transport
        .send(request(&format!("http://127.0.0.1:{port}")), &opts)
        .await;
    assert!(matches!(
        result,
        Err(TransportError::ResponseTooLarge { limit: 32 })
    ));
    fixture.join().unwrap();

    let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(&[b'a'; 4096]).unwrap();
    let wire = encoder.finish().unwrap();
    let mut response = format!(
        "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Length: {}\r\n\r\n",
        wire.len()
    )
    .into_bytes();
    response.extend(wire);
    let (port, fixture) = local_server(response);
    opts.max_response_bytes = Some(8192);
    let result = transport
        .send(request(&format!("http://127.0.0.1:{port}")), &opts)
        .await;
    assert!(matches!(
        result,
        Err(TransportError::ResponseTooLarge { limit: 8192 })
    ));
    fixture.join().unwrap();
}

fn local_server(response: Vec<u8>) -> (u16, thread::JoinHandle<()>) {
    let listener = TcpListener::bind((Ipv4Addr::LOCALHOST, 0)).unwrap();
    let port = listener.local_addr().unwrap().port();
    listener.set_nonblocking(true).unwrap();
    let server = thread::spawn(move || {
        let deadline = std::time::Instant::now() + Duration::from_secs(3);
        let mut stream = loop {
            match listener.accept() {
                Ok((stream, _)) => break stream,
                Err(error)
                    if error.kind() == std::io::ErrorKind::WouldBlock
                        && std::time::Instant::now() < deadline =>
                {
                    thread::sleep(Duration::from_millis(2));
                }
                Err(error) => panic!("loopback fixture received no request: {error}"),
            }
        };
        stream.set_nonblocking(false).unwrap();
        stream
            .set_read_timeout(Some(Duration::from_secs(1)))
            .unwrap();
        let mut read = Vec::new();
        let mut chunk = [0; 1024];
        while !read.windows(4).any(|window| window == b"\r\n\r\n") {
            let count = stream.read(&mut chunk).unwrap();
            assert!(count != 0, "loopback fixture received no header terminator");
            read.extend_from_slice(&chunk[..count]);
        }
        stream.write_all(&response).unwrap();
    });
    (port, server)
}
