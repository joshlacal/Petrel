use std::{
    future::{Future, ready},
    sync::Mutex,
};

use bytes::Bytes;
use http::{Request, Response};

use super::{HttpTransport, SendOptions, TransportError};

pub(crate) struct MockTransport<F> {
    handler: F,
    seen: Mutex<Vec<(Request<Bytes>, SendOptions)>>,
}

impl<F> MockTransport<F> {
    pub(crate) fn new(handler: F) -> Self {
        Self {
            handler,
            seen: Mutex::new(Vec::new()),
        }
    }

    pub(crate) fn seen(&self) -> std::sync::MutexGuard<'_, Vec<(Request<Bytes>, SendOptions)>> {
        self.seen.lock().unwrap()
    }
}

impl<F> HttpTransport for MockTransport<F>
where
    F: Fn(&Request<Bytes>, &SendOptions, usize) -> Result<Response<Bytes>, TransportError>
        + Send
        + Sync,
{
    fn send(
        &self,
        request: Request<Bytes>,
        options: &SendOptions,
    ) -> impl Future<Output = Result<Response<Bytes>, TransportError>> + Send {
        let mut seen = self.seen();
        let ordinal = seen.len();
        let response = (self.handler)(&request, options, ordinal);
        seen.push((request, options.clone()));
        ready(response)
    }
}

pub(crate) fn reply(status: u16, body: &'static [u8]) -> Response<Bytes> {
    Response::builder()
        .status(status)
        .header("Content-Type", "application/json")
        .body(Bytes::from_static(body))
        .unwrap()
}
