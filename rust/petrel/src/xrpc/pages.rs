use std::collections::BTreeSet;

use futures_util::{Stream, stream};
use petrel_core::xrpc::{CursorOutput, CursorParams, XrpcRequest};

use super::{CallOptions, Error, XrpcClient};

impl XrpcClient {
    /// Follow the endpoint's cursor for up to `max_pages` responses.
    ///
    /// Stops at an absent, empty, or repeated cursor, including a repeat of
    /// the starting cursor. An error is yielded once before ending the stream.
    pub fn pages<'a, R>(
        &'a self,
        params: R::Params,
        options: &'a CallOptions,
        max_pages: usize,
    ) -> impl Stream<Item = Result<R::Output, Error<R::Error>>> + 'a
    where
        R: XrpcRequest<Input = ()> + 'a,
        R::Params: CursorParams + Clone + 'a,
        R::Output: CursorOutput + 'a,
    {
        let mut seen = BTreeSet::new();
        if let Some(cursor) = params.cursor() {
            seen.insert(cursor.to_owned());
        }
        let initial = (max_pages != 0).then_some((params, max_pages, seen));
        stream::unfold(initial, move |state| async move {
            let (mut params, pages_left, mut seen) = state?;
            let page = self.send::<R>(params.clone(), (), options).await;
            let next = if pages_left > 1 {
                page.as_ref()
                    .ok()
                    .and_then(CursorOutput::cursor)
                    .filter(|cursor| !cursor.is_empty() && seen.insert((*cursor).to_owned()))
                    .map(|cursor| {
                        params.set_cursor(Some(cursor.to_owned()));
                        (params, pages_left - 1, seen)
                    })
            } else {
                None
            };
            Some((page, next))
        })
    }
}
