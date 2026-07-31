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
    ///
    /// Every field the spec marks required is required here, and a malformed node throws
    /// instead of being skipped: skipping a node also skips each of its right subtrees, and
    /// keys are prefix-compressed against the previous entry, so one bad entry corrupts every
    /// key after it in the node.
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

        // "e" — entries array. Required; a node with no entries serializes as an empty array.
        guard let entries = node["e"] as? [Any] else {
            throw CARReaderError.decodingFailed(
                "MST node \(nodeHex) is missing its required 'e' entries array"
            )
        }

        var lastKey = prefix

        for (index, rawEntry) in entries.enumerated() {
            guard let entry = rawEntry as? [String: Any] else {
                throw CARReaderError.decodingFailed("MST node \(nodeHex) entry \(index) is not a map")
            }

            // "p" — how many characters of the previous key to keep as prefix
            let prefixCount = try entryPrefixCount(entry, nodeHex: nodeHex, index: index)
            guard prefixCount <= lastKey.count else {
                throw CARReaderError.decodingFailed(
                    "MST node \(nodeHex) entry \(index) prefix count \(prefixCount) exceeds previous key length \(lastKey.count)"
                )
            }

            // "k" — key suffix as bytes
            let keySuffix = try entryKeySuffix(entry, nodeHex: nodeHex, index: index)

            // Build full key: take `prefixCount` chars from previous key + suffix
            let prefixPart = String(lastKey.prefix(prefixCount))
            let fullKey = prefixPart + keySuffix
            lastKey = fullKey

            // "v" — value CID (the record)
            guard let valueCID = entry["v"] as? CID else {
                throw CARReaderError.decodingFailed(
                    "MST node \(nodeHex) entry \(index) is missing its required 'v' value CID"
                )
            }
            try onRecord(fullKey, valueCID)

            // "t" — optional right subtree
            if let treeCID = entry["t"] as? CID {
                try walkMSTNode(cid: treeCID, prefix: prefix, onRecord: onRecord)
            }
        }
    }

    // MARK: - Entry Fields

    /// DAG-CBOR unsigned integers decode as `UInt64`; the `Int` branch tolerates an
    /// intermediate that already narrowed the value.
    private func entryPrefixCount(
        _ entry: [String: Any],
        nodeHex: String,
        index: Int
    ) throws -> Int {
        if let p = entry["p"] as? UInt64 {
            guard p <= UInt64(Int.max) else {
                throw CARReaderError.decodingFailed(
                    "MST node \(nodeHex) entry \(index) prefix count \(p) is out of range"
                )
            }
            return Int(p)
        }

        if let p = entry["p"] as? Int {
            guard p >= 0 else {
                throw CARReaderError.decodingFailed(
                    "MST node \(nodeHex) entry \(index) prefix count \(p) is negative"
                )
            }
            return p
        }

        throw CARReaderError.decodingFailed(
            "MST node \(nodeHex) entry \(index) is missing its required integer 'p' prefix count"
        )
    }

    private func entryKeySuffix(
        _ entry: [String: Any],
        nodeHex: String,
        index: Int
    ) throws -> String {
        if let kData = entry["k"] as? Data {
            guard let keySuffix = String(data: kData, encoding: .utf8) else {
                throw CARReaderError.decodingFailed(
                    "MST node \(nodeHex) entry \(index) key suffix is not valid UTF-8"
                )
            }
            return keySuffix
        }

        if let kString = entry["k"] as? String {
            return kString
        }

        throw CARReaderError.decodingFailed(
            "MST node \(nodeHex) entry \(index) is missing its required 'k' key suffix"
        )
    }
}
