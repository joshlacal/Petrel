// CARReader.swift
// Petrel
//
// Reads CAR v1 (Content Addressable aRchive) files.
// Spec: https://ipld.io/specs/transport/car/carv1/

import Foundation
import SwiftCBOR

// MARK: - CARReaderError

public enum CARReaderError: LocalizedError {
  case invalidHeader(String)
  case invalidVarint
  case unexpectedEOF
  case invalidCID(String)
  case blockNotFound(String)
  case decodingFailed(String)

  public var errorDescription: String? {
    switch self {
    case .invalidHeader(let msg): return "Invalid CAR header: \(msg)"
    case .invalidVarint: return "Invalid varint encoding"
    case .unexpectedEOF: return "Unexpected end of data"
    case .invalidCID(let msg): return "Invalid CID: \(msg)"
    case .blockNotFound(let key): return "Block not found for key: \(key)"
    case .decodingFailed(let msg): return "Decoding failed: \(msg)"
    }
  }
}

// MARK: - CARReader

public class CARReader {

  // MARK: - Types

  public struct BlockLocation {
    public let dataOffset: Int
    public let dataLength: Int
  }

  // MARK: - Properties

  private let data: Data
  private var offset: Int = 0

  /// Maps CID hex string → block location in the data
  public private(set) var blockIndex: [String: BlockLocation] = [:]

  /// CID roots from the CAR header
  public private(set) var roots: [CID] = []

  // MARK: - Init

  public init(data: Data) throws {
    self.data = data
    try parseHeader()
    try indexBlocks()
  }

  public convenience init(fileURL: URL) throws {
    let data = try Data(contentsOf: fileURL)
    try self.init(data: data)
  }

  // MARK: - Varint

  /// Reads an unsigned LEB128 varint from the current offset.
  @discardableResult
  public func readVarint() throws -> Int {
    var result: UInt64 = 0
    var shift: UInt64 = 0

    while offset < data.count {
      let byte = data[offset]
      offset += 1

      result |= UInt64(byte & 0x7F) << shift

      if byte & 0x80 == 0 {
        guard result <= UInt64(Int.max) else {
          throw CARReaderError.invalidVarint
        }
        return Int(result)
      }

      shift += 7
      if shift > 63 {
        throw CARReaderError.invalidVarint
      }
    }

    throw CARReaderError.unexpectedEOF
  }

  // MARK: - Header

  private func parseHeader() throws {
    let headerLength = try readVarint()

    guard offset + headerLength <= data.count else {
      throw CARReaderError.unexpectedEOF
    }

    let headerData = data[offset..<(offset + headerLength)]
    offset += headerLength

    guard let cbor = try? CBOR.decode([UInt8](headerData)) else {
      throw CARReaderError.invalidHeader("Failed to decode CBOR header")
    }

    guard case .map(let map) = cbor else {
      throw CARReaderError.invalidHeader("Header is not a CBOR map")
    }

    // Check version
    if let versionCBOR = map[.utf8String("version")] {
      switch versionCBOR {
      case .unsignedInt(let v):
        guard v == 1 else {
          throw CARReaderError.invalidHeader("Unsupported CAR version: \(v)")
        }
      default:
        throw CARReaderError.invalidHeader("Invalid version field type")
      }
    }

    // Parse roots
    if let rootsCBOR = map[.utf8String("roots")] {
      guard case .array(let rootArray) = rootsCBOR else {
        throw CARReaderError.invalidHeader("Roots is not an array")
      }

      for rootItem in rootArray {
        if case .tagged(let tag, let value) = rootItem, tag.rawValue == 42 {
          // Tag 42 CID link
          if case .byteString(let bytes) = value, bytes.count > 1, bytes[0] == 0x00 {
            let cidBytes = Data(bytes.dropFirst())
            let cid = try CID(bytes: cidBytes)
            roots.append(cid)
          }
        } else if case .byteString(let bytes) = rootItem {
          // Raw CID bytes
          let cid = try CID(bytes: Data(bytes))
          roots.append(cid)
        }
      }
    }
  }

  // MARK: - Block Indexing

  private func indexBlocks() throws {
    while offset < data.count {
      let blockStart = offset
      let totalLength: Int
      do {
        totalLength = try readVarint()
      } catch {
        // End of data during varint read — done
        break
      }

      guard totalLength > 0, offset + totalLength <= data.count else {
        break
      }

      let blockDataStart = offset

      // Parse CID from block: version + codec + multihash(algo + length + digest)
      let cidStart = offset

      guard offset < data.count else { break }
      let version = data[offset]
      offset += 1

      if version == 0x12 {
        // CIDv0 (starts with sha2-256 multihash directly) — rare but handle it
        // sha2-256: code=0x12, length=0x20, then 32 bytes digest
        guard offset < data.count else { break }
        let hashLen = data[offset]
        offset += 1
        let digestLen = Int(hashLen)
        guard offset + digestLen <= blockDataStart + totalLength else { break }
        offset += digestLen

        let cidData = data[cidStart..<offset]
        let cidHex = cidData.map { String(format: "%02x", $0) }.joined()

        let dataOffset = offset
        let dataLength = totalLength - (offset - blockDataStart)
        blockIndex[cidHex] = BlockLocation(dataOffset: dataOffset, dataLength: dataLength)
        offset = blockDataStart + totalLength
        continue
      }

      // CIDv1
      guard offset < data.count else { break }
      let codec = data[offset]
      offset += 1

      // Multihash: algorithm + length + digest
      guard offset < data.count else { break }
      let hashAlgo = data[offset]
      offset += 1

      guard offset < data.count else { break }
      let hashLen = data[offset]
      offset += 1

      let digestLen = Int(hashLen)
      guard offset + digestLen <= blockDataStart + totalLength else { break }
      offset += digestLen

      let cidData = data[cidStart..<offset]
      let cidHex = cidData.map { String(format: "%02x", $0) }.joined()

      let dataOffset = offset
      let dataLength = totalLength - (offset - blockDataStart)

      blockIndex[cidHex] = BlockLocation(dataOffset: dataOffset, dataLength: dataLength)

      offset = blockDataStart + totalLength
    }
  }

  // MARK: - Block Access

  /// Retrieves and decodes the CBOR block for a given CID hex key.
  public func decodeBlock(for key: String) throws -> Any? {
    guard let location = blockIndex[key] else {
      throw CARReaderError.blockNotFound(key)
    }

    let blockData = data[location.dataOffset..<(location.dataOffset + location.dataLength)]

    guard let cbor = try? CBOR.decode([UInt8](blockData)) else {
      throw CARReaderError.decodingFailed("Failed to decode CBOR for block \(key)")
    }

    return try DAGCBOR.decodeCBORItem(cbor)
  }

  /// Returns raw block data for a given CID hex key.
  public func rawBlockData(for key: String) throws -> Data {
    guard let location = blockIndex[key] else {
      throw CARReaderError.blockNotFound(key)
    }
    return Data(data[location.dataOffset..<(location.dataOffset + location.dataLength)])
  }

  /// Returns the CID hex string for a CID struct by encoding its bytes.
  public static func cidHex(from cid: CID) -> String {
    cid.bytes.map { String(format: "%02x", $0) }.joined()
  }
}
