use std::collections::{BTreeMap, HashSet};
use std::fmt;
use std::sync::Arc;

use async_lock::Mutex;
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use petrel_core::{Cid, Value, dagcbor};

use crate::block_store::RepositoryBlock;
use crate::car::varint;
use crate::error::CARError;

/// Streaming destination for encoded CAR v1 bytes (`CARByteSink`).
pub trait CARByteSink: MaybeSend + MaybeSync + fmt::Debug {
    fn write_bytes<'a>(&'a self, chunk: &'a [u8]) -> BoxFuture<'a, Result<(), CARError>>;

    fn finish(&self) -> BoxFuture<'_, Result<(), CARError>> {
        Box::pin(async { Ok(()) })
    }
}

/// In-memory [`CARByteSink`] (`DataCARByteSink`).
#[derive(Debug, Clone, Default)]
pub struct DataCARByteSink {
    buffer: Arc<Mutex<Vec<u8>>>,
}

impl DataCARByteSink {
    pub fn new() -> Self {
        Self::default()
    }

    pub async fn into_bytes(&self) -> Vec<u8> {
        self.buffer.lock().await.clone()
    }
}

impl CARByteSink for DataCARByteSink {
    fn write_bytes<'a>(&'a self, chunk: &'a [u8]) -> BoxFuture<'a, Result<(), CARError>> {
        Box::pin(async move {
            self.buffer.lock().await.extend_from_slice(chunk);
            Ok(())
        })
    }
}

#[cfg(not(target_arch = "wasm32"))]
mod file_sink {
    use std::fs::{File, OpenOptions};
    use std::io::{BufWriter, Write};
    use std::path::Path;
    use std::sync::Arc;

    use async_lock::Mutex;
    use petrel::rt::BoxFuture;

    use crate::error::CARError;

    use super::CARByteSink;

    /// File-backed [`CARByteSink`] (`FileCARByteSink`).
    #[derive(Debug, Clone)]
    pub struct FileCARByteSink {
        writer: Arc<Mutex<BufWriter<File>>>,
    }

    impl FileCARByteSink {
        pub fn create(path: impl AsRef<Path>) -> Result<Self, CARError> {
            let path = path.as_ref();
            if let Some(parent) = path.parent()
                && !parent.as_os_str().is_empty()
            {
                std::fs::create_dir_all(parent).map_err(|err| CARError::Io(err.to_string()))?;
            }
            let file = OpenOptions::new()
                .create(true)
                .write(true)
                .truncate(true)
                .open(path)
                .map_err(|err| CARError::Io(err.to_string()))?;
            Ok(Self {
                writer: Arc::new(Mutex::new(BufWriter::new(file))),
            })
        }

        pub async fn synchronize(&self) -> Result<(), CARError> {
            let mut guard = self.writer.lock().await;
            guard.flush().map_err(|err| CARError::Io(err.to_string()))?;
            guard
                .get_ref()
                .sync_all()
                .map_err(|err| CARError::Io(err.to_string()))?;
            Ok(())
        }
    }

    impl CARByteSink for FileCARByteSink {
        fn write_bytes<'a>(&'a self, chunk: &'a [u8]) -> BoxFuture<'a, Result<(), CARError>> {
            Box::pin(async move {
                let mut guard = self.writer.lock().await;
                guard
                    .write_all(chunk)
                    .map_err(|err| CARError::Io(err.to_string()))?;
                Ok(())
            })
        }

        fn finish(&self) -> BoxFuture<'_, Result<(), CARError>> {
            Box::pin(async move {
                let mut guard = self.writer.lock().await;
                guard.flush().map_err(|err| CARError::Io(err.to_string()))?;
                Ok(())
            })
        }
    }
}

#[cfg(not(target_arch = "wasm32"))]
pub use file_sink::FileCARByteSink;

/// Encodes canonical CAR v1 headers and deduplicated block frames.
pub(crate) fn encode_header(roots: &[Cid]) -> Result<Vec<u8>, CARError> {
    if roots.is_empty() {
        return Err(CARError::MissingRoots);
    }
    let mut header_map = BTreeMap::new();
    header_map.insert(
        "roots".to_owned(),
        Value::Array(roots.iter().cloned().map(Value::Link).collect()),
    );
    header_map.insert("version".to_owned(), Value::Integer(1));
    let header_cbor = dagcbor::encode(&Value::Object(header_map));
    let mut out = Vec::with_capacity(9 + header_cbor.len());
    varint::push_varint(header_cbor.len() as u64, &mut out)?;
    out.extend_from_slice(&header_cbor);
    Ok(out)
}

pub(crate) fn encode_frame(cid: &Cid, payload: &[u8]) -> Result<Vec<u8>, CARError> {
    let cid_bytes = cid.as_bytes();
    let frame_len = cid_bytes.len() + payload.len();
    let mut out = Vec::with_capacity(9 + frame_len);
    varint::push_varint(frame_len as u64, &mut out)?;
    out.extend_from_slice(cid_bytes);
    out.extend_from_slice(payload);
    Ok(out)
}

/// Writes a CAR v1 archive into an in-memory buffer, validating that all roots
/// exist and deduplicating repeated blocks with conflict checking.
pub fn write_car_to_vec(roots: &[Cid], blocks: &[RepositoryBlock]) -> Result<Vec<u8>, CARError> {
    let mut out = encode_header(roots)?;
    let mut seen: HashSet<&Cid> = HashSet::with_capacity(blocks.len());
    for block in blocks {
        if !seen.insert(&block.cid) {
            continue;
        }
        let cid_bytes = block.cid.as_bytes();
        varint::push_varint((cid_bytes.len() + block.bytes.len()) as u64, &mut out)?;
        out.extend_from_slice(cid_bytes);
        out.extend_from_slice(&block.bytes);
    }
    Ok(out)
}

/// Streams CAR v1 header + deduplicated blocks to `sink`.
pub async fn write_car_to_sink<S: CARByteSink + ?Sized>(
    roots: &[Cid],
    blocks: &[RepositoryBlock],
    sink: &S,
) -> Result<(), CARError> {
    let header = encode_header(roots)?;
    sink.write_bytes(&header).await?;
    let mut seen = HashSet::with_capacity(blocks.len());
    for block in blocks {
        if !seen.insert(&block.cid) {
            continue;
        }
        let frame = encode_frame(&block.cid, &block.bytes)?;
        sink.write_bytes(&frame).await?;
    }
    sink.finish().await?;
    Ok(())
}
