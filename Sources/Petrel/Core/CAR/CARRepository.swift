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
        /// Records that decoded but matched no generated Lexicon type, so they were
        /// preserved as `.unknownType`. They are counted in `decodedCount` as well;
        /// a non-zero value here means schema drift, not a clean decode.
        public let downgradedCount: Int
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
        var downgradedCount = 0
        var failedCount = 0

        guard let commitRoot = reader.roots.first else {
            return Stats(
                blockCount: reader.rawBlockIndex.count,
                recordCount: 0,
                decodedCount: 0,
                downgradedCount: 0,
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

            do {
                let rawData = try reader.rawBlockData(for: recordCID.bytes)
                let value = try decodeRecordCBOR(rawData)

                let record = Record(
                    collection: collection,
                    rkey: rkey,
                    cid: recordCID,
                    value: value,
                    rawCBOR: rawData
                )

                decodedCount += 1
                if case .unknownType = value {
                    downgradedCount += 1
                }
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
            blockCount: reader.rawBlockIndex.count,
            recordCount: recordCount,
            decodedCount: decodedCount,
            downgradedCount: downgradedCount,
            failedCount: failedCount,
            roots: reader.roots
        )
    }

    // MARK: - CBOR Decoding

    /// Decodes raw DAG-CBOR data into an `ATProtocolValueContainer`.
    /// Flow: CBOR bytes → SwiftCBOR parse → ATProtocolValueContainer.fromCBOR
    public static func decodeRecordCBOR(_ data: Data) throws -> ATProtocolValueContainer {
        guard !data.isEmpty else {
            throw CARReaderError.decodingFailed("Empty CBOR data")
        }
        guard let cborItem = try? CBOR.decode([UInt8](data)) else {
            throw CARReaderError.decodingFailed("Failed to parse CBOR")
        }
        let container = try ATProtocolValueContainer.fromCBOR(
            cborItem,
            stringifyUnsignedAboveIntMax: true
        )

        switch cborItem {
        case .map, .array:
            return container
        default:
            throw CARReaderError.decodingFailed("CBOR root is not a map or array")
        }
    }
}
