// MSTTraverser.swift
// Petrel
//
// Traverses the Merkle Search Tree (MST) structure used by AT Protocol repositories.
// Ref: https://atproto.com/specs/repository#mst-structure

import Foundation

// MARK: - MSTTraverser

public class MSTTraverser {
    /// Maximum allowable depth when traversing an MST.
    ///
    /// AT Protocol Merkle Search Trees use a fanout of 4 (2 bits per level) over SHA-256 digests
    /// (256 bits). The theoretical maximum height for any key's prefix is 256 / 2 = 128 layers.
    /// Any tree traversal exceeding 128 levels indicates a synthetic or cyclic structure.
    private static let maxMSTDepth = 128

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
        guard let commitNode = try reader.decodeBlock(for: commitCID.bytes) as? [String: Any] else {
            throw CARReaderError.decodingFailed("Failed to decode commit node")
        }

        // The commit node's "data" field is the MST root CID
        guard let dataCID = commitNode["data"] as? CID else {
            throw CARReaderError.decodingFailed("Commit node missing 'data' CID")
        }

        var visited = Set<CID>()
        var lastKeyBytes: [UInt8]? = nil
        var stack: [MSTFrame] = [
            try makeFrame(cid: dataCID, depth: 0, visited: &visited),
        ]
        while let frameIndex = stack.indices.last {
            // 1. Process left subtree if not yet processed
            if !stack[frameIndex].processedLeft {
                stack[frameIndex].processedLeft = true
                if let leftCID = stack[frameIndex].leftCID {
                    let nextDepth = stack[frameIndex].depth + 1
                    stack.append(try makeFrame(cid: leftCID, depth: nextDepth, visited: &visited))
                    continue
                }
            }

            // 2. Process next entry
            let entryIndex = stack[frameIndex].nextEntryIndex
            if entryIndex < stack[frameIndex].entries.count {
                stack[frameIndex].nextEntryIndex += 1

                guard let entry = stack[frameIndex].entries[entryIndex] as? [String: Any] else {
                    throw CARReaderError.decodingFailed(
                        "MST node \(CARReader.cidHex(from: stack[frameIndex].cid)) entry \(entryIndex) is not a map"
                    )
                }

                // "p" — how many bytes of the previous key to keep as prefix
                let prefixCount = try entryPrefixCount(entry, cid: stack[frameIndex].cid, index: entryIndex)
                guard prefixCount <= stack[frameIndex].keyBytes.count else {
                    throw CARReaderError.decodingFailed(
                        "MST node \(CARReader.cidHex(from: stack[frameIndex].cid)) entry \(entryIndex) prefix count \(prefixCount) exceeds previous key length \(stack[frameIndex].keyBytes.count)"
                    )
                }

                // Truncate running key buffer to prefixCount bytes
                if stack[frameIndex].keyBytes.count > prefixCount {
                    stack[frameIndex].keyBytes.removeSubrange(prefixCount ..< stack[frameIndex].keyBytes.count)
                }

                // "k" — key suffix as bytes
                try appendEntryKeySuffix(from: entry, to: &stack[frameIndex].keyBytes, cid: stack[frameIndex].cid, index: entryIndex)

                // Validate UTF-8 and materialize full key String once for onRecord
                guard let fullKey = String(bytes: stack[frameIndex].keyBytes, encoding: .utf8) else {
                    throw CARReaderError.decodingFailed(
                        "MST node \(CARReader.cidHex(from: stack[frameIndex].cid)) entry \(entryIndex) key suffix is not valid UTF-8"
                    )
                }

                // Validate path structure: must be exactly collection/rkey (no additional slashes)
                let parts = fullKey.split(separator: "/", omittingEmptySubsequences: false)
                guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
                    throw CARReaderError.decodingFailed(
                        "MST node \(CARReader.cidHex(from: stack[frameIndex].cid)) entry \(entryIndex) has invalid path structure: '\(fullKey)'"
                    )
                }

                // Validate strictly increasing order across traversal
                if let prevKeyBytes = lastKeyBytes {
                    let currentBytes = stack[frameIndex].keyBytes
                    guard currentBytes.lexicographicallyPrecedes(prevKeyBytes) == false && currentBytes != prevKeyBytes else {
                        throw CARReaderError.decodingFailed(
                            "MST keys out of order or duplicate: '\(fullKey)'"
                        )
                    }
                }
                lastKeyBytes = stack[frameIndex].keyBytes

                // "v" — value CID (the record)
                guard let valueCID = entry["v"] as? CID else {
                    throw CARReaderError.decodingFailed(
                        "MST node \(CARReader.cidHex(from: stack[frameIndex].cid)) entry \(entryIndex) is missing its required 'v' value CID"
                    )
                }

                try onRecord(fullKey, valueCID)
                // If this entry has a right subtree 't', push it to the stack
                if let treeCID = entry["t"] as? CID {
                    let nextDepth = stack[frameIndex].depth + 1
                    stack.append(try makeFrame(cid: treeCID, depth: nextDepth, visited: &visited))
                    continue
                }
            } else {
                // Node entries completed: pop frame
                stack.removeLast()
            }
        }
    }

    // MARK: - Frame Construction

    private struct MSTFrame {
        let cid: CID
        let depth: Int
        let leftCID: CID?
        let entries: [Any]
        var nextEntryIndex: Int
        var keyBytes: [UInt8]
        var processedLeft: Bool
    }

    private func makeFrame(
        cid: CID,
        depth: Int,
        visited: inout Set<CID>
    ) throws -> MSTFrame {
        guard depth <= Self.maxMSTDepth else {
            throw CARReaderError.decodingFailed(
                "MST depth limit exceeded (\(depth) > \(Self.maxMSTDepth)) at node \(CARReader.cidHex(from: cid))"
            )
        }

        guard visited.insert(cid).inserted else {
            throw CARReaderError.decodingFailed(
                "Cycle detected in MST: node \(CARReader.cidHex(from: cid)) has already been visited"
            )
        }

        guard let node = try reader.decodeBlock(for: cid.bytes) as? [String: Any] else {
            throw CARReaderError.decodingFailed("Failed to decode MST node \(CARReader.cidHex(from: cid))")
        }

        let leftCID = node["l"] as? CID

        // "e" — entries array. Required; a node with no entries serializes as an empty array.
        guard let entries = node["e"] as? [Any] else {
            throw CARReaderError.decodingFailed(
                "MST node \(CARReader.cidHex(from: cid)) is missing its required 'e' entries array"
            )
        }

        var keyBytes = [UInt8]()
        keyBytes.reserveCapacity(64)

        return MSTFrame(
            cid: cid,
            depth: depth,
            leftCID: leftCID,
            entries: entries,
            nextEntryIndex: 0,
            keyBytes: keyBytes,
            processedLeft: false
        )
    }

    // MARK: - Entry Fields

    /// DAG-CBOR unsigned integers decode as `UInt64`; the `Int` branch tolerates an
    /// intermediate that already narrowed the value.
    private func entryPrefixCount(
        _ entry: [String: Any],
        cid: CID,
        index: Int
    ) throws -> Int {
        if let p = entry["p"] as? UInt64 {
            guard p <= UInt64(Int.max) else {
                throw CARReaderError.decodingFailed(
                    "MST node \(CARReader.cidHex(from: cid)) entry \(index) prefix count \(p) is out of range"
                )
            }
            return Int(p)
        }

        if let p = entry["p"] as? Int {
            guard p >= 0 else {
                throw CARReaderError.decodingFailed(
                    "MST node \(CARReader.cidHex(from: cid)) entry \(index) prefix count \(p) is negative"
                )
            }
            return p
        }

        throw CARReaderError.decodingFailed(
            "MST node \(CARReader.cidHex(from: cid)) entry \(index) is missing its required integer 'p' prefix count"
        )
    }

    private func appendEntryKeySuffix(
        from entry: [String: Any],
        to buffer: inout [UInt8],
        cid: CID,
        index: Int
    ) throws {
        if let kData = entry["k"] as? Data {
            buffer.append(contentsOf: kData)
            return
        }

        if let kBytes = entry["k"] as? [UInt8] {
            buffer.append(contentsOf: kBytes)
            return
        }

        if let kString = entry["k"] as? String {
            buffer.append(contentsOf: kString.utf8)
            return
        }

        throw CARReaderError.decodingFailed(
            "MST node \(CARReader.cidHex(from: cid)) entry \(index) is missing its required 'k' key suffix"
        )
    }
}
