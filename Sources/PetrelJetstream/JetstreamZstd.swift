import Foundation
import libzstd

enum JetstreamZstdError: Error, Sendable, Equatable {
  case decompressionFailed(String)
  case compressionFailed(String)
  case invalidFrame
  case frameTooLarge(declared: UInt64, limit: Int)
  case dictionaryLoadFailed
}

/// Thin wrappers over the libzstd C API.
///
/// Segment blocks are plain standalone zstd frames (CRC enabled server-side,
/// no dictionary); websocket compression uses a dictionary held by
/// `JetstreamZstdDictionaryDecoder`.
enum JetstreamZstd {
  /// `ZSTD_CONTENTSIZE_UNKNOWN` / `ZSTD_CONTENTSIZE_ERROR` are C macros that
  /// do not import into Swift.
  private static let contentSizeUnknown = UInt64.max
  private static let contentSizeError = UInt64.max - 1

  /// Decompress one standalone zstd frame. `maxDecompressedSize` guards
  /// against zstd bombs from untrusted input.
  static func decompress(_ frame: Data, maxDecompressedSize: Int = 1 << 30) throws -> Data {
    guard !frame.isEmpty else { throw JetstreamZstdError.invalidFrame }
    return try frame.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Data in
      let contentSize = ZSTD_getFrameContentSize(src.baseAddress, src.count)
      let declared = UInt64(contentSize)
      if declared == contentSizeError {
        throw JetstreamZstdError.invalidFrame
      }
      if declared == contentSizeUnknown {
        return try streamingDecompress(src, maxDecompressedSize: maxDecompressedSize)
      }
      guard declared <= UInt64(maxDecompressedSize) else {
        throw JetstreamZstdError.frameTooLarge(declared: declared, limit: maxDecompressedSize)
      }
      var out = Data(count: Int(declared))
      let written = out.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) in
        ZSTD_decompress(dst.baseAddress, dst.count, src.baseAddress, src.count)
      }
      if ZSTD_isError(written) != 0 {
        throw JetstreamZstdError.decompressionFailed(Self.errorName(written))
      }
      out.removeSubrange(written..<out.count)
      return out
    }
  }

  private static func streamingDecompress(
    _ src: UnsafeRawBufferPointer, maxDecompressedSize: Int
  ) throws -> Data {
    guard let dctx = ZSTD_createDCtx() else {
      throw JetstreamZstdError.decompressionFailed("ZSTD_createDCtx")
    }
    defer { ZSTD_freeDCtx(dctx) }

    var input = ZSTD_inBuffer(src: src.baseAddress, size: src.count, pos: 0)
    let chunkSize = ZSTD_DStreamOutSize()
    var chunk = [UInt8](repeating: 0, count: chunkSize)
    var out = Data()

    while input.pos < input.size {
      let ret = chunk.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) -> Int in
        var output = ZSTD_outBuffer(dst: dst.baseAddress, size: dst.count, pos: 0)
        let r = ZSTD_decompressStream(dctx, &output, &input)
        if ZSTD_isError(r) == 0 {
          out.append(contentsOf: dst.bindMemory(to: UInt8.self).prefix(output.pos))
        }
        return r
      }
      if ZSTD_isError(ret) != 0 {
        throw JetstreamZstdError.decompressionFailed(Self.errorName(ret))
      }
      guard out.count <= maxDecompressedSize else {
        throw JetstreamZstdError.frameTooLarge(declared: UInt64(out.count), limit: maxDecompressedSize)
      }
      if ret == 0 { break }
    }
    return out
  }

  /// Single-shot compression. Production code never compresses; tests use
  /// this to build block fixtures.
  static func compress(_ data: Data, level: Int32 = 3) throws -> Data {
    let bound = ZSTD_compressBound(data.count)
    var out = Data(count: bound)
    let written = out.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) in
      data.withUnsafeBytes { (src: UnsafeRawBufferPointer) in
        ZSTD_compress(dst.baseAddress, dst.count, src.baseAddress, src.count, level)
      }
    }
    if ZSTD_isError(written) != 0 {
      throw JetstreamZstdError.compressionFailed(Self.errorName(written))
    }
    out.removeSubrange(written..<out.count)
    return out
  }

  /// Dictionary compression; test fixtures for the compressed-websocket path.
  static func compress(_ data: Data, dictionary: Data, level: Int32 = 3) throws -> Data {
    let cdict = dictionary.withUnsafeBytes { (dict: UnsafeRawBufferPointer) in
      ZSTD_createCDict(dict.baseAddress, dict.count, level)
    }
    guard let cdict else { throw JetstreamZstdError.dictionaryLoadFailed }
    defer { ZSTD_freeCDict(cdict) }
    guard let cctx = ZSTD_createCCtx() else {
      throw JetstreamZstdError.compressionFailed("ZSTD_createCCtx")
    }
    defer { ZSTD_freeCCtx(cctx) }

    let bound = ZSTD_compressBound(data.count)
    var out = Data(count: bound)
    let written = out.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) in
      data.withUnsafeBytes { (src: UnsafeRawBufferPointer) in
        ZSTD_compress_usingCDict(cctx, dst.baseAddress, dst.count, src.baseAddress, src.count, cdict)
      }
    }
    if ZSTD_isError(written) != 0 {
      throw JetstreamZstdError.compressionFailed(Self.errorName(written))
    }
    out.removeSubrange(written..<out.count)
    return out
  }

  /// Dictionary ID embedded in a raw dictionary blob; 0 (nil) means not a
  /// structured dictionary.
  static func dictionaryID(of dictionary: Data) -> UInt32? {
    let id = dictionary.withUnsafeBytes { (dict: UnsafeRawBufferPointer) in
      ZSTD_getDictID_fromDict(dict.baseAddress, dict.count)
    }
    return id == 0 ? nil : id
  }

  private static func errorName(_ code: Int) -> String {
    String(cString: ZSTD_getErrorName(code))
  }
}

/// Holds a `ZSTD_DDict` for websocket frame decompression. Not thread-safe by
/// design: one instance per subscription runner (actor-confined).
final class JetstreamZstdDictionaryDecoder {
  private let ddict: OpaquePointer
  private let dctx: OpaquePointer
  private let maxDecompressedSize: Int

  init(dictionary: Data, maxDecompressedSize: Int = 1 << 27) throws {
    let ddict = dictionary.withUnsafeBytes { (dict: UnsafeRawBufferPointer) in
      ZSTD_createDDict(dict.baseAddress, dict.count)
    }
    guard let ddict else { throw JetstreamZstdError.dictionaryLoadFailed }
    guard let dctx = ZSTD_createDCtx() else {
      ZSTD_freeDDict(ddict)
      throw JetstreamZstdError.dictionaryLoadFailed
    }
    self.ddict = ddict
    self.dctx = dctx
    self.maxDecompressedSize = maxDecompressedSize
  }

  deinit {
    ZSTD_freeDDict(ddict)
    ZSTD_freeDCtx(dctx)
  }

  func decompress(_ frame: Data) throws -> Data {
    guard !frame.isEmpty else { throw JetstreamZstdError.invalidFrame }
    return try frame.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Data in
      let contentSize = ZSTD_getFrameContentSize(src.baseAddress, src.count)
      let declared = UInt64(contentSize)
      // Websocket frames always carry the content size (single-shot encoder).
      guard declared != UInt64.max, declared != UInt64.max - 1 else {
        throw JetstreamZstdError.invalidFrame
      }
      guard declared <= UInt64(maxDecompressedSize) else {
        throw JetstreamZstdError.frameTooLarge(declared: declared, limit: maxDecompressedSize)
      }
      var out = Data(count: Int(declared))
      let written = out.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) in
        ZSTD_decompress_usingDDict(dctx, dst.baseAddress, dst.count, src.baseAddress, src.count, ddict)
      }
      if ZSTD_isError(written) != 0 {
        throw JetstreamZstdError.decompressionFailed(String(cString: ZSTD_getErrorName(written)))
      }
      out.removeSubrange(written..<out.count)
      return out
    }
  }
}
