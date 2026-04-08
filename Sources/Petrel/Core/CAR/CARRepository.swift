// CARRepository.swift
// Petrel
//
// High-level API for parsing AT Protocol CAR repository exports.
// Delegates to CARReader for binary parsing, MSTTraverser for tree walking,
// and DAGCBOR for record decoding.

import Foundation
import SwiftCBOR

// MARK: - CARRepository

public enum CARRepository {

  // MARK: - Types

  public struct Record {
    public let collection: String
    public let rkey: String
    public let cid: CID
    public let value: ATProtocolValueContainer
    public let rawCBOR: Data
  }

  public struct Stats {
    public let blockCount: Int
    public let recordCount: Int
    public let decodedCount: Int
    public let failedCount: Int
    public let roots: [CID]
  }

  // MARK: - Parsing

  /// Parses a CAR file, walking the MST and decoding each record.
  ///
  /// - Parameters:
  ///   - fileURL: Path to the `.car` file.
  ///   - onRecord: Called for each decoded record.
  /// - Returns: Aggregate statistics about the parse.
  public static func parse(
    fileURL: URL,
    onRecord: (Record) throws -> Void
  ) throws -> Stats {
    let reader = try CARReader(fileURL: fileURL)

    let traverser = MSTTraverser(reader: reader)
    var recordCount = 0
    var decodedCount = 0
    var failedCount = 0

    guard let commitRoot = reader.roots.first else {
      return Stats(
        blockCount: reader.blockIndex.count,
        recordCount: 0,
        decodedCount: 0,
        failedCount: 0,
        roots: reader.roots
      )
    }

    try traverser.walkRepository(commitCID: commitRoot) { path, recordCID in
      recordCount += 1

      // Split "collection/rkey" path
      let parts = path.split(separator: "/", maxSplits: 1)
      let collection = parts.count > 0 ? String(parts[0]) : ""
      let rkey = parts.count > 1 ? String(parts[1]) : ""

      let cidHex = CARReader.cidHex(from: recordCID)

      do {
        let rawData = try reader.rawBlockData(for: cidHex)
        let value = try decodeRecordCBOR(rawData)

        let record = Record(
          collection: collection,
          rkey: rkey,
          cid: recordCID,
          value: value,
          rawCBOR: rawData
        )

        decodedCount += 1
        try onRecord(record)
      } catch {
        failedCount += 1

        // Still emit the record with a decode error
        let errorRecord = Record(
          collection: collection,
          rkey: rkey,
          cid: recordCID,
          value: .decodeError("Failed to decode: \(error.localizedDescription)"),
          rawCBOR: Data()
        )
        try onRecord(errorRecord)
      }
    }

    return Stats(
      blockCount: reader.blockIndex.count,
      recordCount: recordCount,
      decodedCount: decodedCount,
      failedCount: failedCount,
      roots: reader.roots
    )
  }

  // MARK: - CBOR Decoding

  /// Decodes raw DAG-CBOR data into an `ATProtocolValueContainer`.
  ///
  /// Flow: CBOR bytes → SwiftCBOR parse → DAGCBOR.decodeCBORItem → Swift dict → JSON → ATProtocolValueContainer
  public static func decodeRecordCBOR(_ data: Data) throws -> ATProtocolValueContainer {
    guard !data.isEmpty else {
      throw CARReaderError.decodingFailed("Empty CBOR data")
    }

    guard let cborItem = try? CBOR.decode([UInt8](data)) else {
      throw CARReaderError.decodingFailed("Failed to parse CBOR")
    }

    let intermediate = try DAGCBOR.decodeCBORItem(cborItem)

    // Convert to JSON-compatible form for ATProtocolValueContainer decoding
    let jsonData: Data
    if let dict = intermediate as? [String: Any] {
      jsonData = try jsonSerialize(dict)
    } else if let array = intermediate as? [Any] {
      jsonData = try JSONSerialization.data(withJSONObject: array)
    } else {
      throw CARReaderError.decodingFailed("CBOR root is not a map or array")
    }

    return try JSONDecoder().decode(ATProtocolValueContainer.self, from: jsonData)
  }

  // MARK: - Helpers

  /// Converts a decoded CBOR dictionary to JSON Data, handling CID objects.
  private static func jsonSerialize(_ value: Any) throws -> Data {
    let jsonCompatible = makeJSONCompatible(value)
    return try JSONSerialization.data(withJSONObject: jsonCompatible)
  }

  /// Recursively converts CBOR-decoded values to JSON-compatible types.
  /// CID objects become `{ "$link": "bafy..." }` for ATProtocolValueContainer.
  private static func makeJSONCompatible(_ value: Any) -> Any {
    switch value {
    case let cid as CID:
      return ["$link": cid.string]
    case let dict as [String: Any]:
      var result = [String: Any]()
      for (k, v) in dict {
        result[k] = makeJSONCompatible(v)
      }
      return result
    case let array as [Any]:
      return array.map { makeJSONCompatible($0) }
    case let uint64 as UInt64:
      if uint64 <= UInt64(Int.max) {
        return Int(uint64)
      }
      return String(uint64)
    case let int64 as Int64:
      return Int(int64)
    case let data as Data:
      return ["$bytes": data.base64EncodedString()]
    case Optional<Any>.none:
      return NSNull()
    default:
      return value
    }
  }
}
