pub mod reader;
pub mod varint;
pub mod writer;

#[cfg(not(target_arch = "wasm32"))]
pub use reader::FileCARByteSource;
pub use reader::{
    CARArchive, CARByteSource, CARHeader, CARReader, CARRepository, DataCARByteSource, ParsedCAR,
    PublicRepositoryCAR,
};
#[cfg(not(target_arch = "wasm32"))]
pub use writer::FileCARByteSink;
pub use writer::{CARByteSink, DataCARByteSink};
