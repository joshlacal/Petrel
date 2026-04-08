// MSTTraverser.swift
// Petrel
//
// Traverses the Merkle Search Tree (MST) structure used by AT Protocol repositories.
// Ref: https://atproto.com/specs/repository#mst-structure

import Foundation

// MARK: - MSTTraverser

public class MSTTraverser {

  private let reader: CARReader

  public init(reader: CARReader) {
    self.reader = reader
  }

  /// Walks the repository starting from a commit CID, calling `onRecord` for each leaf record.
  ///
  /// The commit node contains a `data` field pointing to the MST root.
  /// MST nodes have `l` (left subtree), `e` (entries array) where each entry has
  /// `k` (key suffix bytes), `p` (prefix count), `v` (value CID), and `t` (right subtree).
  public func walkRepository(commitCID: CID, onRecord: (String, CID) throws -> Void) throws {
    let commitHex = CARReader.cidHex(from: commitCID)

    guard let commitNode = try reader.decodeBlock(for: commitHex) as? [String: Any] else {
      throw CARReaderError.decodingFailed("Failed to decode commit node")
    }

    // The commit node's "data" field is the MST root CID
    guard let dataCID = commitNode["data"] as? CID else {
      throw CARReaderError.decodingFailed("Commit node missing 'data' CID")
    }

    try walkMSTNode(cid: dataCID, prefix: "", onRecord: onRecord)
  }

  // MARK: - MST Node Walking

  private func walkMSTNode(
    cid: CID,
    prefix: String,
    onRecord: (String, CID) throws -> Void
  ) throws {
    let nodeHex = CARReader.cidHex(from: cid)

    guard let node = try reader.decodeBlock(for: nodeHex) as? [String: Any] else {
      throw CARReaderError.decodingFailed("Failed to decode MST node \(nodeHex)")
    }

    // "l" — optional left subtree CID
    if let leftCID = node["l"] as? CID {
      try walkMSTNode(cid: leftCID, prefix: prefix, onRecord: onRecord)
    }

    // "e" — entries array
    guard let entries = node["e"] as? [[String: Any]] else {
      return // Leaf with no entries
    }

    var lastKey = prefix

    for entry in entries {
      // "p" — how many characters of the previous key to keep as prefix
      let prefixCount: Int
      if let p = entry["p"] as? UInt64 {
        prefixCount = Int(p)
      } else if let p = entry["p"] as? Int {
        prefixCount = p
      } else {
        prefixCount = 0
      }

      // "k" — key suffix as bytes
      let keySuffix: String
      if let kData = entry["k"] as? Data {
        keySuffix = String(data: kData, encoding: .utf8) ?? ""
      } else if let kString = entry["k"] as? String {
        keySuffix = kString
      } else {
        continue
      }

      // Build full key: take `prefixCount` chars from previous key + suffix
      let prefixPart = String(lastKey.prefix(prefixCount))
      let fullKey = prefixPart + keySuffix
      lastKey = fullKey

      // "v" — value CID (the record)
      if let valueCID = entry["v"] as? CID {
        try onRecord(fullKey, valueCID)
      }

      // "t" — optional right subtree
      if let treeCID = entry["t"] as? CID {
        try walkMSTNode(cid: treeCID, prefix: prefix, onRecord: onRecord)
      }
    }
  }
}
