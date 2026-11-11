import Foundation
import PetrelCore

/// Where a page of `GET /export` starts.
public enum PLCExportCursor: Sendable, Equatable, CustomStringConvertible {
    /// After the operation with this sequence number. The directory answers
    /// in the `sequenced_op` format. `.sequence(0)` starts at the beginning.
    case sequence(UInt64)
    /// After this `YYYY-MM-DDTHH:mm:ss.sssZ` timestamp. The directory
    /// answers in the legacy format, which carries `nullified` but no
    /// sequence number. The specification discourages this format.
    case timestamp(String)

    /// The value of the `after` query parameter.
    public var description: String {
        switch self {
        case let .sequence(value): String(value)
        case let .timestamp(value): value
        }
    }
}

/// One line of the directory's bulk export, in either export format.
///
/// The same shape is sent, one JSON object per WebSocket message, on
/// `/export/stream`; decode those messages with ``init(jsonLine:)``.
public struct PLCExportEntry: Sendable, Equatable {
    /// The identity the operation belongs to.
    public let did: String
    /// The operation.
    public let operation: PLCSignedOperation
    /// The CID of ``operation``. Verified against the operation on decode.
    public let cid: String
    /// When the directory accepted the operation.
    public let createdAt: String
    /// The directory's sequence number. Present in the `sequenced_op`
    /// format only. An annotation by this directory, not a property of the
    /// operation: a mirror may number the same operations differently.
    public let sequence: UInt64?
    /// Whether the directory considers the operation nullified. Present in
    /// the legacy format only.
    public let nullified: Bool?

    /// Creates an entry from already-validated parts.
    public init(
        did: String,
        operation: PLCSignedOperation,
        cid: String,
        createdAt: String,
        sequence: UInt64?,
        nullified: Bool?
    ) {
        self.did = did
        self.operation = operation
        self.cid = cid
        self.createdAt = createdAt
        self.sequence = sequence
        self.nullified = nullified
    }

    /// The cursor that continues an export after this entry: its sequence
    /// number when it has one, otherwise its timestamp.
    public var cursor: PLCExportCursor {
        sequence.map(PLCExportCursor.sequence) ?? .timestamp(createdAt)
    }

    /// Decodes one export line and checks that `cid` is the hash of
    /// `operation`.
    ///
    /// For a genesis operation the caller can go further without any other
    /// data: ``PLCOperationCodec/verifyGenesis(_:expectedDID:)`` proves the
    /// DID and the signature. Later operations need their predecessor.
    ///
    /// - Throws: ``PetrelPLCError/malformed(_:)``;
    ///   ``PetrelPLCError/unauthorized(_:)`` for a CID that does not match.
    public init(jsonLine data: Data) throws {
        try StrictJSON.validate(data)
        // The envelope goes through `JSONDecoder`, which tells a JSON number
        // from a JSON boolean; the operation needs the dynamic form.
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let operationObject = raw["operation"] else {
            throw PetrelPLCError.malformed("PLC export entry is malformed")
        }
        let did = envelope.did
        let cid = envelope.cid
        let createdAt = envelope.createdAt
        let sequence = envelope.seq
        let nullified = envelope.nullified
        try PLCOperationCodec.validateCanonicalDID(did)
        guard envelope.type == nil || envelope.type == "sequenced_op" else {
            throw PetrelPLCError.malformed("PLC export entry type is unsupported")
        }
        let operation = try PLCOperationCodec.decodeSigned(jsonObject: operationObject)
        guard try operation.cid.string == cid else {
            throw PetrelPLCError.unauthorized("PLC export operation CID is invalid")
        }
        self.init(
            did: did,
            operation: operation,
            cid: cid,
            createdAt: createdAt,
            sequence: sequence,
            nullified: nullified
        )
    }

    private struct Envelope: Decodable {
        let did: String
        let cid: String
        let createdAt: String
        let seq: UInt64?
        let nullified: Bool?
        let type: String?
    }

    /// Decodes a JSON-lines export body. Empty lines are skipped.
    public static func decode(jsonLines data: Data) throws -> [PLCExportEntry] {
        try data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true)
            .compactMap { line -> PLCExportEntry? in
                let trimmed = line.last == UInt8(ascii: "\r") ? line.dropLast() : line
                guard !trimmed.isEmpty else { return nil }
                return try PLCExportEntry(jsonLine: Data(trimmed))
            }
    }
}
