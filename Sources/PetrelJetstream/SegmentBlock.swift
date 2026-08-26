import Foundation
import Petrel
import PetrelCore
import PetrelFirehose
import SwiftCBOR

/// One decoded columnar row from a Jetstream v2 segment block.
struct SegmentEvent: Sendable {
  let seq: Int64
  let witnessedAtUS: Int64
  let indexedAtUS: Int64
  /// Kind value 1...7 (1=Create, 2=Update, 3=Delete, 4=Identity, 5=Account, 6=Sync, 7=CreateResync).
  let kind: UInt8
  let collection: String
  let did: String
  let rkey: String
  let rev: String
  /// Raw DAG-CBOR payload; empty when event_len == 0 (e.g. deletes).
  let payload: Data

  /// Display timestamp in unix microseconds (indexed_at if non-zero, else witnessed_at).
  var timeUS: Int64 {
    indexedAtUS != 0 ? indexedAtUS : witnessedAtUS
  }

  /// Converts this raw segment row into a high-level `JetstreamEvent`.
  /// Returns `nil` only for kinds outside 1...7.
  func toJetstreamEvent() -> JetstreamEvent? {
    switch kind {
    case 1, 7:
      let recordJSON = decodePayloadJSON(payload)
      return .commit(
        JetstreamCommitEvent(
          seq: seq,
          did: did,
          timeUS: timeUS,
          rev: rev,
          operation: .create,
          collection: collection,
          rkey: rkey,
          cid: nil,
          recordJSON: recordJSON
        )
      )
    case 2:
      let recordJSON = decodePayloadJSON(payload)
      return .commit(
        JetstreamCommitEvent(
          seq: seq,
          did: did,
          timeUS: timeUS,
          rev: rev,
          operation: .update,
          collection: collection,
          rkey: rkey,
          cid: nil,
          recordJSON: recordJSON
        )
      )
    case 3:
      return .commit(
        JetstreamCommitEvent(
          seq: seq,
          did: did,
          timeUS: timeUS,
          rev: rev,
          operation: .delete,
          collection: collection,
          rkey: rkey,
          cid: nil,
          recordJSON: nil
        )
      )
    case 4:
      let identity = decodePayloadDetail(ComAtprotoSyncSubscribeRepos.Identity.self, from: payload)
      return .identity(
        JetstreamIdentityEvent(
          seq: seq,
          did: did,
          timeUS: timeUS,
          identity: identity
        )
      )
    case 5:
      let account = decodePayloadDetail(ComAtprotoSyncSubscribeRepos.Account.self, from: payload)
      return .account(
        JetstreamAccountEvent(
          seq: seq,
          did: did,
          timeUS: timeUS,
          account: account
        )
      )
    case 6:
      let sync = decodePayloadDetail(ComAtprotoSyncSubscribeRepos.Sync.self, from: payload)
      return .sync(
        JetstreamSyncEvent(
          seq: seq,
          did: did,
          timeUS: timeUS,
          sync: sync
        )
      )
    default:
      return nil
    }
  }

  private func decodePayloadJSON(_ data: Data) -> Data? {
    guard !data.isEmpty else { return nil }
    guard let cborItem = try? CBOR.decode([UInt8](data)) else { return nil }
    guard let intermediateValue = try? DAGCBOR.decodeCBORItem(cborItem) else { return nil }
    return try? DAGCBORJSONBridge.jsonData(from: intermediateValue)
  }

  private func decodePayloadDetail<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
    guard let jsonData = decodePayloadJSON(data) else { return nil }
    return try? JSONCoders.decode(type, from: jsonData)
  }
}

enum SegmentBlockError: Error, Sendable, Equatable {
  case truncated
  case invalidHeader(String)
  case notSealed
  case unsupportedVersion(UInt16)
  case badMagic
}

/// Decodes columnar Jetstream v2 segment blocks.
enum SegmentBlockDecoder {
  private static let maxEventCount = 262_144

  /// Decompresses a standalone zstd frame and decodes its columnar events.
  static func decodeFrame(_ frame: Data) throws -> [SegmentEvent] {
    let uncompressed = try JetstreamZstd.decompress(frame)
    return try decodeUncompressed(uncompressed)
  }

  /// Decodes uncompressed columnar block bytes.
  static func decodeUncompressed(_ data: Data) throws -> [SegmentEvent] {
    guard data.count >= 4 else {
      throw SegmentBlockError.truncated
    }

    let eventCount = Int(data.withUnsafeBytes { ptr in
      UInt32(littleEndian: ptr.loadUnaligned(fromByteOffset: 0, as: UInt32.self))
    })

    guard eventCount <= maxEventCount else {
      throw SegmentBlockError.invalidHeader("event_count \(eventCount) exceeds maximum \(maxEventCount)")
    }

    if eventCount == 0 {
      guard data.count == 4 else {
        throw SegmentBlockError.invalidHeader("trailing bytes after zero-event block")
      }
      return []
    }

    let fixedColumnsSize = 34 * eventCount
    let fixedTotal = 4 + fixedColumnsSize
    guard data.count >= fixedTotal else {
      throw SegmentBlockError.truncated
    }

    let n = eventCount
    let base = 4

    return try data.withUnsafeBytes { ptr in
      let seqOffset = base
      let witnessedOffset = seqOffset + 8 * n
      let indexedOffset = witnessedOffset + 8 * n
      let kindOffset = indexedOffset + 8 * n
      let collectionLenOffset = kindOffset + 1 * n
      let didLenOffset = collectionLenOffset + 1 * n
      let rkeyLenOffset = didLenOffset + 2 * n
      let revLenOffset = rkeyLenOffset + 1 * n
      let eventLenOffset = revLenOffset + 1 * n

      // Validate kinds and compute length sums
      var totalCollectionLen = 0
      var totalDidLen = 0
      var totalRkeyLen = 0
      var totalRevLen = 0
      var totalEventLen = 0

      for i in 0..<n {
        let kind = ptr.loadUnaligned(fromByteOffset: kindOffset + i, as: UInt8.self)
        guard (1...7).contains(kind) else {
          throw SegmentBlockError.invalidHeader("invalid event kind: \(kind)")
        }

        totalCollectionLen += Int(ptr.loadUnaligned(fromByteOffset: collectionLenOffset + i, as: UInt8.self))
        totalDidLen += Int(UInt16(littleEndian: ptr.loadUnaligned(fromByteOffset: didLenOffset + 2 * i, as: UInt16.self)))
        totalRkeyLen += Int(ptr.loadUnaligned(fromByteOffset: rkeyLenOffset + i, as: UInt8.self))
        totalRevLen += Int(ptr.loadUnaligned(fromByteOffset: revLenOffset + i, as: UInt8.self))
        totalEventLen += Int(UInt32(littleEndian: ptr.loadUnaligned(fromByteOffset: eventLenOffset + 4 * i, as: UInt32.self)))
      }

      let totalVarLen = totalCollectionLen + totalDidLen + totalRkeyLen + totalRevLen + totalEventLen
      let expectedTotal = fixedTotal + totalVarLen

      guard data.count >= expectedTotal else {
        throw SegmentBlockError.truncated
      }
      guard data.count == expectedTotal else {
        throw SegmentBlockError.invalidHeader("trailing bytes after var region: expected \(expectedTotal), got \(data.count)")
      }

      var currentVarOffset = fixedTotal
      let collectionsBase = currentVarOffset
      currentVarOffset += totalCollectionLen
      let didsBase = currentVarOffset
      currentVarOffset += totalDidLen
      let rkeysBase = currentVarOffset
      currentVarOffset += totalRkeyLen
      let revsBase = currentVarOffset
      currentVarOffset += totalRevLen
      let payloadsBase = currentVarOffset

      var currentCollectionOffset = collectionsBase
      var currentDidOffset = didsBase
      var currentRkeyOffset = rkeysBase
      var currentRevOffset = revsBase
      var currentPayloadOffset = payloadsBase

      var events = [SegmentEvent]()
      events.reserveCapacity(n)

      for i in 0..<n {
        let rawSeq = ptr.loadUnaligned(fromByteOffset: seqOffset + 8 * i, as: UInt64.self)
        let seq = Int64(bitPattern: UInt64(littleEndian: rawSeq))

        let rawWitnessed = ptr.loadUnaligned(fromByteOffset: witnessedOffset + 8 * i, as: UInt64.self)
        let witnessedAtUS = Int64(bitPattern: UInt64(littleEndian: rawWitnessed))

        let rawIndexed = ptr.loadUnaligned(fromByteOffset: indexedOffset + 8 * i, as: UInt64.self)
        let indexedAtUS = Int64(bitPattern: UInt64(littleEndian: rawIndexed))

        let kind = ptr.loadUnaligned(fromByteOffset: kindOffset + i, as: UInt8.self)

        let collectionLen = Int(ptr.loadUnaligned(fromByteOffset: collectionLenOffset + i, as: UInt8.self))
        let didLen = Int(UInt16(littleEndian: ptr.loadUnaligned(fromByteOffset: didLenOffset + 2 * i, as: UInt16.self)))
        let rkeyLen = Int(ptr.loadUnaligned(fromByteOffset: rkeyLenOffset + i, as: UInt8.self))
        let revLen = Int(ptr.loadUnaligned(fromByteOffset: revLenOffset + i, as: UInt8.self))
        let eventLen = Int(UInt32(littleEndian: ptr.loadUnaligned(fromByteOffset: eventLenOffset + 4 * i, as: UInt32.self)))

        let collectionBytes = ptr.baseAddress!.advanced(by: currentCollectionOffset)
        let collection = String(decoding: UnsafeRawBufferPointer(start: collectionBytes, count: collectionLen), as: UTF8.self)
        currentCollectionOffset += collectionLen

        let didBytes = ptr.baseAddress!.advanced(by: currentDidOffset)
        let did = String(decoding: UnsafeRawBufferPointer(start: didBytes, count: didLen), as: UTF8.self)
        currentDidOffset += didLen

        let rkeyBytes = ptr.baseAddress!.advanced(by: currentRkeyOffset)
        let rkey = String(decoding: UnsafeRawBufferPointer(start: rkeyBytes, count: rkeyLen), as: UTF8.self)
        currentRkeyOffset += rkeyLen

        let revBytes = ptr.baseAddress!.advanced(by: currentRevOffset)
        let rev = String(decoding: UnsafeRawBufferPointer(start: revBytes, count: revLen), as: UTF8.self)
        currentRevOffset += revLen

        let payloadData: Data
        if eventLen > 0 {
          let payloadBytes = ptr.baseAddress!.advanced(by: currentPayloadOffset)
          payloadData = Data(bytes: payloadBytes, count: eventLen)
          currentPayloadOffset += eventLen
        } else {
          payloadData = Data()
        }

        events.append(
          SegmentEvent(
            seq: seq,
            witnessedAtUS: witnessedAtUS,
            indexedAtUS: indexedAtUS,
            kind: kind,
            collection: collection,
            did: did,
            rkey: rkey,
            rev: rev,
            payload: payloadData
          )
        )
      }

      return events
    }
  }
}

/// Sequential `.jss` archive segment file reader.
final class SegmentFileReader: @unchecked Sendable {
  let blockCount: Int
  private let fileHandle: FileHandle
  private let footerOffset: UInt64
  private var currentOffset: UInt64 = 256
  private var isClosed: Bool = false
  private let lock = NSLock()

  init(fileURL: URL) throws {
    let handle = try FileHandle(forReadingFrom: fileURL)
    guard let header = try handle.read(upToCount: 256), header.count == 256 else {
      try? handle.close()
      throw SegmentBlockError.truncated
    }

    guard header[0] == 0x6A, header[1] == 0x73, header[2] == 0x73, header[3] == 0x30 else {
      try? handle.close()
      throw SegmentBlockError.badMagic
    }

    let checksum = header.withUnsafeBytes { ptr in
      UInt64(littleEndian: ptr.loadUnaligned(fromByteOffset: 4, as: UInt64.self))
    }
    guard checksum != 0 else {
      try? handle.close()
      throw SegmentBlockError.notSealed
    }

    let version = header.withUnsafeBytes { ptr in
      UInt16(littleEndian: ptr.loadUnaligned(fromByteOffset: 12, as: UInt16.self))
    }
    guard version == 1 else {
      try? handle.close()
      throw SegmentBlockError.unsupportedVersion(version)
    }

    let blockCountU32 = header.withUnsafeBytes { ptr in
      UInt32(littleEndian: ptr.loadUnaligned(fromByteOffset: 14, as: UInt32.self))
    }
    self.blockCount = Int(blockCountU32)

    let footerOffset = header.withUnsafeBytes { ptr in
      UInt64(littleEndian: ptr.loadUnaligned(fromByteOffset: 58, as: UInt64.self))
    }
    guard footerOffset >= 256 else {
      try? handle.close()
      throw SegmentBlockError.invalidHeader("footer_offset \(footerOffset) < 256")
    }

    self.fileHandle = handle
    self.footerOffset = footerOffset
  }

  deinit {
    close()
  }

  /// Reads and decodes the next zstd-compressed block frame from the file.
  /// Returns `nil` when the reader reaches `footer_offset`.
  func nextBlock() throws -> [SegmentEvent]? {
    lock.lock()
    defer { lock.unlock() }

    if isClosed {
      return nil
    }

    let current = currentOffset
    if current >= footerOffset {
      return nil
    }

    guard current + 8 <= footerOffset else {
      throw SegmentBlockError.truncated
    }

    try fileHandle.seek(toOffset: current)
    guard let prefixData = try fileHandle.read(upToCount: 8), prefixData.count == 8 else {
      throw SegmentBlockError.truncated
    }

    let compressedLength = prefixData.withUnsafeBytes { ptr in
      UInt64(littleEndian: ptr.loadUnaligned(as: UInt64.self))
    }

    guard current + 8 + compressedLength <= footerOffset else {
      throw SegmentBlockError.truncated
    }

    guard let frameData = try fileHandle.read(upToCount: Int(compressedLength)),
          frameData.count == Int(compressedLength) else {
      throw SegmentBlockError.truncated
    }

    currentOffset = current + 8 + compressedLength
    return try SegmentBlockDecoder.decodeFrame(frameData)
  }

  func close() {
    lock.lock()
    defer { lock.unlock() }

    if !isClosed {
      isClosed = true
      try? fileHandle.close()
    }
  }
}
