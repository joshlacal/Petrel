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

  /// Recursively decodes the JSON emitted by `DAGCBORJSONBridge` without
  /// requiring every value to be an object. Exact DAG-JSON link and bytes
  /// objects recover their semantic container cases so DAG-CBOR re-encoding
  /// retains Tag 42 and byte-string wire forms.
  private struct CARJSONValue: Decodable {
    let value: ATProtocolValueContainer

    init(from decoder: Decoder) throws {
      if let primitive = try Self.decodePrimitive(from: decoder) {
        value = primitive
        return
      }
      if let array = try Self.decodeArray(from: decoder) {
        value = .array(array)
        return
      }

      let objectContainer = try decoder.container(keyedBy: CARJSONCodingKey.self)
      value = try Self.decodeObjectValue(from: objectContainer, decoder: decoder)
    }

    private static func decodePrimitive(
      from decoder: Decoder
    ) throws -> ATProtocolValueContainer? {
      let singleValue = try decoder.singleValueContainer()

      if singleValue.decodeNil() {
        return .null
      }
      if let boolValue = try? singleValue.decode(Bool.self) {
        return .bool(boolValue)
      }
      if let intValue = try? singleValue.decode(Int.self) {
        return .number(intValue)
      }
      if let stringValue = try? singleValue.decode(String.self) {
        // CAR's bridge policy intentionally represents unsigned integers above
        // Int.max as decimal strings, so preserve all JSON strings verbatim.
        return .string(stringValue)
      }
      return nil
    }

    private static func decodeArray(
      from decoder: Decoder
    ) throws -> [ATProtocolValueContainer]? {
      guard var arrayContainer = try? decoder.unkeyedContainer() else {
        return nil
      }

      var array = [ATProtocolValueContainer]()
      while !arrayContainer.isAtEnd {
        if try arrayContainer.decodeNil() {
          array.append(.null)
        } else {
          try array.append(arrayContainer.decode(CARJSONValue.self).value)
        }
      }
      return array
    }

    private static func decodeObjectValue(
      from container: KeyedDecodingContainer<CARJSONCodingKey>,
      decoder: Decoder
    ) throws -> ATProtocolValueContainer {
      if let specialObject = try decodeSpecialObject(from: container) {
        return specialObject
      }

      if let typeKey = container.allKeys.first(where: { $0.stringValue == "$type" }) {
        if let typeValue = try? container.decode(String.self, forKey: typeKey) {
          if let typedValue = try? ATProtocolValueContainer(from: decoder) {
            if case .unknownType = typedValue {
              return try decodeUnknownType(typeValue, from: container)
            }
            return typedValue
          }
          return try decodeUnknownType(typeValue, from: container)
        }
      }

      return try .object(decodeObject(from: container))
    }

    private static func decodeUnknownType(
      _ typeValue: String,
      from container: KeyedDecodingContainer<CARJSONCodingKey>
    ) throws -> ATProtocolValueContainer {
      return try .unknownType(
        typeValue,
        .object(decodeObject(from: container))
      )
    }

    private static func decodeSpecialObject(
      from container: KeyedDecodingContainer<CARJSONCodingKey>
    ) throws -> ATProtocolValueContainer? {
      guard container.allKeys.count == 1, let onlyKey = container.allKeys.first else {
        return nil
      }

      switch onlyKey.stringValue {
      case "$link":
        let cidString = try container.decode(String.self, forKey: onlyKey)
        return try .link(ATProtoLink(cidString: cidString))
      case "$bytes":
        let base64String = try container.decode(String.self, forKey: onlyKey)
        guard let data = Data(base64Encoded: base64String) else {
          throw DecodingError.dataCorruptedError(
            forKey: onlyKey,
            in: container,
            debugDescription: "Invalid base64 in exact $bytes object"
          )
        }
        return .bytes(Bytes(data: data))
      default:
        return nil
      }
    }

    private static func decodeObject(
      from container: KeyedDecodingContainer<CARJSONCodingKey>
    ) throws -> [String: ATProtocolValueContainer] {
      var object = [String: ATProtocolValueContainer]()
      for key in container.allKeys {
        if try container.decodeNil(forKey: key) {
          object[key.stringValue] = .null
        } else {
          object[key.stringValue] = try container.decode(CARJSONValue.self, forKey: key).value
        }
      }
      return object
    }
  }

  private struct CARJSONCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
      self.stringValue = stringValue
      intValue = nil
    }

    init?(intValue: Int) {
      stringValue = String(intValue)
      self.intValue = intValue
    }
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

    let isMapRoot = intermediate is [String: Any]
    guard isMapRoot || intermediate is [Any] else {
      throw CARReaderError.decodingFailed("CBOR root is not a map or array")
    }

    let jsonData = try DAGCBORJSONBridge.jsonData(
      from: intermediate,
      unsignedIntegerPolicy: .stringifyAboveIntMax
    )

    return try JSONDecoder().decode(CARJSONValue.self, from: jsonData).value
  }
}
