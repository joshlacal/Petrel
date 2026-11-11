import Foundation
import PetrelCore
import PetrelCrypto

/// The state of a PLC identity: what `GET /:did/data` returns, and what the
/// newest valid operation of the identity's log establishes.
public struct PLCDocumentData: Sendable, Equatable {
    /// The identity.
    public let did: String
    /// Priority-ordered rotation keys, as `did:key` strings.
    public let rotationKeys: [String]
    /// Verification method id (no `#`) to `did:key`.
    public let verificationMethods: [String: String]
    /// Priority-ordered aliases, for atproto `at://<handle>`.
    public let alsoKnownAs: [String]
    /// Service id (no `#`) to service.
    public let services: [String: PLCService]

    /// Creates a state value.
    public init(
        did: String,
        rotationKeys: [String],
        verificationMethods: [String: String],
        alsoKnownAs: [String],
        services: [String: PLCService]
    ) {
        self.did = did
        self.rotationKeys = rotationKeys
        self.verificationMethods = verificationMethods
        self.alsoKnownAs = alsoKnownAs
        self.services = services
    }

    /// The atproto handle: the first `at://` alias, without the prefix.
    public var handle: String? {
        alsoKnownAs.first { $0.hasPrefix("at://") }.map { String($0.dropFirst(5)) }
    }

    /// The endpoint of the `atproto_pds` service, when it has the
    /// `AtprotoPersonalDataServer` type.
    public var pdsEndpoint: String? {
        guard let service = services[PLCATProfile.pdsServiceID],
              service.type == PLCATProfile.pdsServiceType else { return nil }
        return service.endpoint
    }

    /// The `atproto` verification method: the repository signing key as a
    /// `did:key`.
    public var atprotoSigningKey: String? {
        verificationMethods[PLCATProfile.signingKeyID]
    }
}

/// One entry of an identity's audit log (`GET /:did/log/audit`).
public struct PLCAuditEntry: Sendable, Equatable {
    /// The identity the operation belongs to.
    public let did: String
    /// The operation.
    public let operation: PLCSignedOperation
    /// The CID of ``operation``.
    public let cid: String
    /// Whether the operation was superseded by a recovery.
    ///
    /// In entries returned by ``PLCDirectoryClient/getAuditLog(did:)`` this
    /// is the directory's claim. In a ``PLCVerifiedAuditLog`` it has been
    /// recomputed from the signatures and timestamps.
    public let nullified: Bool
    /// When the directory accepted the operation, as
    /// `YYYY-MM-DDTHH:mm:ss.sssZ`. This is the directory's assertion; it is
    /// not covered by any signature.
    public let createdAt: String

    /// Creates an entry. Nothing is verified here; see ``PLCAuditLogVerifier``.
    public init(
        did: String,
        operation: PLCSignedOperation,
        cid: String,
        nullified: Bool,
        createdAt: String
    ) {
        self.did = did
        self.operation = operation
        self.cid = cid
        self.nullified = nullified
        self.createdAt = createdAt
    }
}

/// An audit log whose every operation has been checked: CIDs recomputed,
/// the DID derived from the genesis operation, each signature verified
/// against the rotation keys in force, and nullification recomputed from the
/// recovery rules.
///
/// Only ``PLCAuditLogVerifier`` creates values of this type.
public struct PLCVerifiedAuditLog: Sendable, Equatable {
    /// The identity the log belongs to.
    public let did: String
    /// Every entry in directory order, with ``PLCAuditEntry/nullified``
    /// recomputed.
    public let entries: [PLCAuditEntry]
    /// For each entry of ``entries``, the `did:key` of the rotation key
    /// whose signature it carries.
    public let signers: [String]
    /// The newest entry that has not been nullified: the operation that
    /// defines the identity's current state, and the one an update names in
    /// `prev`.
    public let head: PLCAuditEntry

    /// The entries that have not been nullified, oldest first.
    public var activeEntries: [PLCAuditEntry] {
        entries.filter { !$0.nullified }
    }

    /// Whether the identity has been deactivated.
    public var isTombstoned: Bool {
        head.operation.isTombstone
    }

    /// The identity's current state, or `nil` when it is tombstoned.
    public var documentData: PLCDocumentData? {
        head.operation.documentData(did: did)
    }

    /// Checks an operation that is about to be submitted against this log:
    /// its `prev` must name ``head``, the identity must not be tombstoned,
    /// and it must be signed by one of the current rotation keys.
    ///
    /// This proves who signed the operation and where it goes in the chain,
    /// not what it changes. For an operation someone else signed for you —
    /// for example the one a PDS returns from
    /// `com.atproto.identity.signPlcOperation` — also compare the state it
    /// establishes with what you asked for; `PetrelPLCPDS` does both in
    /// `verifyNextOperation(_:applying:)`.
    ///
    /// - Returns: The index of the signing key in the current rotation keys.
    /// - Throws: ``PetrelPLCError/tombstoned(did:)``;
    ///   ``PetrelPLCError/unauthorized(_:)``.
    @discardableResult
    public func verifyNextOperation(_ operation: PLCSignedOperation) throws -> Int {
        guard let rotationKeys = head.operation.rotationKeys else {
            throw PetrelPLCError.tombstoned(did: did)
        }
        guard let prev = operation.prev,
              PLCAuditLogVerifier.cidsMatch(canonical: head.cid, candidate: prev) else {
            throw PetrelPLCError.unauthorized(
                "PLC operation prev does not name the identity's current operation"
            )
        }
        return try PLCOperationCodec.verify(operation, authorizedRotationKeys: rotationKeys)
    }
}

/// Offline verification of PLC operation logs.
///
/// Nothing here touches the network: pass in a log obtained from any
/// directory, mirror or archive and the result does not depend on trusting
/// where it came from, except for the `createdAt` timestamps, which only the
/// directory can assert and which decide the 72-hour recovery window.
public enum PLCAuditLogVerifier {
    /// The window in which a higher-authority rotation key may nullify
    /// operations signed by a lower-authority one: 72 hours.
    public static let recoveryWindow: TimeInterval = 72 * 60 * 60

    /// The longest log that will be processed.
    public static let maximumEntries = 10_000

    /// Decodes the JSON body of `GET /:did/log/audit` without verifying
    /// signatures or the chain.
    ///
    /// Each entry's `cid` is checked against the hash of its operation, so
    /// the entries are internally consistent, but `nullified` is whatever
    /// the directory said and nothing proves the operations belong to the
    /// DID. Call ``verify(_:did:)`` for that.
    ///
    /// - Throws: ``PetrelPLCError/malformed(_:)``;
    ///   ``PetrelPLCError/unauthorized(_:)`` for a CID that does not match.
    public static func decode(_ data: Data, did: String) throws -> [PLCAuditEntry] {
        try PLCOperationCodec.validateCanonicalDID(did)
        try StrictJSON.validate(data)
        guard let rawEntries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !rawEntries.isEmpty,
              rawEntries.count <= maximumEntries else {
            throw PetrelPLCError.malformed("PLC audit log is malformed")
        }
        return try rawEntries.map { raw in
            guard let entryDID = raw["did"] as? String,
                  entryDID == did,
                  let operationObject = raw["operation"],
                  let cidText = raw["cid"] as? String,
                  let nullified = raw["nullified"] as? Bool,
                  let createdAt = raw["createdAt"] as? String else {
                throw PetrelPLCError.malformed("PLC audit entry is malformed")
            }
            let operation = try PLCOperationCodec.decodeSigned(jsonObject: operationObject)
            guard try operation.cid.string == cidText else {
                throw PetrelPLCError.unauthorized("PLC audit operation CID is invalid")
            }
            return PLCAuditEntry(
                did: entryDID,
                operation: operation,
                cid: cidText,
                nullified: nullified,
                createdAt: createdAt
            )
        }
    }

    /// Decodes and verifies the JSON body of `GET /:did/log/audit`.
    public static func verify(json data: Data, did: String) throws -> PLCVerifiedAuditLog {
        try verify(decode(data, did: did), did: did)
    }

    /// Verifies an audit log for `did`, following the procedure in the
    /// specification's "Audit Logs" section and the reference server's
    /// acceptance rules:
    ///
    /// 1. Every entry's CID is recomputed from its operation.
    /// 2. The first entry is a genesis operation (regular or legacy
    ///    `create`) whose hash is the DID and which is signed by one of its
    ///    own rotation keys.
    /// 3. Every later entry names in `prev` an operation that is still
    ///    valid at that point, which is not a tombstone, and is signed by
    ///    one of that operation's rotation keys.
    /// 4. An entry whose `prev` is not the newest valid operation is a
    ///    recovery: it must be signed by a rotation key of strictly higher
    ///    authority than the one that signed the first operation it
    ///    displaces, and be dated within 72 hours of that operation. The
    ///    displaced operations become nullified.
    ///
    /// The `nullified` flags of the input are ignored and recomputed.
    ///
    /// - Throws: ``PetrelPLCError/unauthorized(_:)`` for any trust violation;
    ///   ``PetrelPLCError/malformed(_:)`` for a structurally invalid log.
    public static func verify(_ entries: [PLCAuditEntry], did: String) throws -> PLCVerifiedAuditLog {
        try PLCOperationCodec.validateCanonicalDID(did)
        guard !entries.isEmpty, entries.count <= maximumEntries else {
            throw PetrelPLCError.malformed("PLC audit log is malformed")
        }

        var timestamps = [Int64]()
        timestamps.reserveCapacity(entries.count)
        var signers = [String]()
        signers.reserveCapacity(entries.count)
        var seenCIDs = Set<String>()
        for (index, entry) in entries.enumerated() {
            guard entry.did == did,
                  let timestamp = plcTimestampMilliseconds(entry.createdAt),
                  timestamps.last.map({ timestamp >= $0 }) ?? true else {
                throw PetrelPLCError.malformed("PLC audit entry is malformed")
            }
            timestamps.append(timestamp)
            guard try entry.operation.cid.string == entry.cid,
                  seenCIDs.insert(entry.cid).inserted else {
                throw PetrelPLCError.unauthorized("PLC audit operation CID is invalid")
            }
            if index == 0 {
                guard entry.operation.prev == nil, !entry.operation.isTombstone else {
                    throw PetrelPLCError.unauthorized("PLC audit does not start with genesis")
                }
            } else if entry.operation.prev == nil {
                throw PetrelPLCError.unauthorized("PLC audit contains multiple genesis operations")
            }
        }

        // Genesis: the DID is the hash of the operation, which is signed by
        // one of the keys it declares.
        let genesis = entries[0].operation
        guard try PLCOperationCodec.genesisDID(for: genesis) == did,
              let genesisKeys = genesis.rotationKeys else {
            throw PetrelPLCError.unauthorized("PLC genesis DID does not match operation")
        }
        try signers.append(PLCOperationCodec.verifyReturningKey(
            genesis, authorizedRotationKeys: genesisKeys
        ).key.didKey)

        // Replay the log the way the directory accepted it. `active` holds
        // the indices of the operations that are valid so far.
        var active = [0]
        for proposedIndex in entries.indices.dropFirst() {
            let proposed = entries[proposedIndex]
            guard let proposedPrev = proposed.operation.prev,
                  let parentPosition = active.firstIndex(where: {
                      cidsMatch(canonical: entries[$0].cid, candidate: proposedPrev)
                  }) else {
                throw PetrelPLCError.unauthorized("PLC audit operation prev is not active")
            }
            guard let rotationKeys = entries[active[parentPosition]].operation.rotationKeys else {
                throw PetrelPLCError.unauthorized("PLC audit operation follows a tombstone")
            }
            if parentPosition == active.count - 1 {
                try signers.append(PLCOperationCodec.verifyReturningKey(
                    proposed.operation, authorizedRotationKeys: rotationKeys
                ).key.didKey)
                active.append(proposedIndex)
                continue
            }

            // Recovery: `proposed` forks from an earlier operation and
            // displaces everything after it.
            let firstDisputedIndex = active[parentPosition + 1]
            let disputedSignerIndex = try PLCOperationCodec.verify(
                entries[firstDisputedIndex].operation,
                authorizedRotationKeys: rotationKeys
            )
            guard disputedSignerIndex > 0 else {
                throw PetrelPLCError.unauthorized(
                    "PLC recovery cannot supersede an equal-authority operation"
                )
            }
            try signers.append(PLCOperationCodec.verifyReturningKey(
                proposed.operation,
                authorizedRotationKeys: Array(rotationKeys[..<disputedSignerIndex])
            ).key.didKey)
            let recoveryAge = timestamps[proposedIndex] - timestamps[firstDisputedIndex]
            guard recoveryAge >= 0, recoveryAge <= Int64(recoveryWindow * 1_000) else {
                throw PetrelPLCError.unauthorized("PLC recovery exceeds the 72-hour window")
            }
            active.removeSubrange((parentPosition + 1)...)
            active.append(proposedIndex)
        }

        let activeSet = Set(active)
        let verified = entries.enumerated().map { index, entry in
            PLCAuditEntry(
                did: entry.did,
                operation: entry.operation,
                cid: entry.cid,
                nullified: !activeSet.contains(index),
                createdAt: entry.createdAt
            )
        }
        // `active` always holds at least the genesis index.
        return PLCVerifiedAuditLog(
            did: did,
            entries: verified,
            signers: signers,
            head: verified[active[active.count - 1]]
        )
    }

    /// Verifies a linear operation log — the body of `GET /:did/log`, which
    /// lists only the currently valid operations — and returns the state it
    /// leads to. The counterpart of the reference library's
    /// `validateOperationLog`.
    ///
    /// - Returns: The identity's state, or `nil` if the log ends in a
    ///   tombstone.
    /// - Throws: ``PetrelPLCError/unauthorized(_:)`` when the genesis hash,
    ///   a `prev` link or a signature does not verify, or when anything
    ///   follows a tombstone.
    public static func validateOperationLog(
        _ operations: [PLCSignedOperation],
        did: String
    ) throws -> PLCDocumentData? {
        guard let first = operations.first, operations.count <= maximumEntries else {
            throw PetrelPLCError.malformed("PLC operation log is malformed")
        }
        try PLCOperationCodec.verifyGenesis(first, expectedDID: did)
        var previous = first
        for operation in operations.dropFirst() {
            guard let rotationKeys = previous.rotationKeys else {
                throw PetrelPLCError.unauthorized("PLC operation follows a tombstone")
            }
            guard let prev = operation.prev,
                  try cidsMatch(canonical: previous.cid.string, candidate: prev) else {
                throw PetrelPLCError.unauthorized("PLC operation prev does not match the log")
            }
            _ = try PLCOperationCodec.verify(operation, authorizedRotationKeys: rotationKeys)
            previous = operation
        }
        return previous.documentData(did: did)
    }

    /// Whether a `prev` value names the operation with CID `canonical`. The
    /// reference implementation compares parsed CIDs, so an alternative
    /// spelling of the same CID (upper-case base32) is accepted.
    static func cidsMatch(canonical: String, candidate: String) -> Bool {
        if canonical == candidate { return true }
        return (try? CID.parse(candidate))?.string == canonical
    }
}

/// Parses a directory timestamp (`YYYY-MM-DDTHH:mm:ss.sssZ`, the output of
/// JavaScript's `Date.toISOString`) to milliseconds since the Unix epoch.
/// Returns `nil` for any other form.
func plcTimestampMilliseconds(_ value: String) -> Int64? {
    let bytes = Array(value.utf8)
    guard bytes.count == 24,
          bytes[4] == UInt8(ascii: "-"),
          bytes[7] == UInt8(ascii: "-"),
          bytes[10] == UInt8(ascii: "T"),
          bytes[13] == UInt8(ascii: ":"),
          bytes[16] == UInt8(ascii: ":"),
          bytes[19] == UInt8(ascii: "."),
          bytes[23] == UInt8(ascii: "Z") else {
        return nil
    }
    func number(_ range: Range<Int>) -> Int64? {
        var result: Int64 = 0
        for index in range {
            let byte = bytes[index]
            guard byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") else { return nil }
            result = result * 10 + Int64(byte - UInt8(ascii: "0"))
        }
        return result
    }
    guard let year = number(0 ..< 4), let month = number(5 ..< 7), let day = number(8 ..< 10),
          let hour = number(11 ..< 13), let minute = number(14 ..< 16),
          let second = number(17 ..< 19), let millisecond = number(20 ..< 23),
          (1 ... 12).contains(month), hour <= 23, minute <= 59, second <= 59 else {
        return nil
    }
    let isLeapYear = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    let daysInMonth: [Int64] = [31, isLeapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    guard day >= 1, day <= daysInMonth[Int(month) - 1] else { return nil }
    // Days since 1970-01-01 in the proleptic Gregorian calendar.
    let shiftedYear = month <= 2 ? year - 1 : year
    let era = (shiftedYear >= 0 ? shiftedYear : shiftedYear - 399) / 400
    let yearOfEra = shiftedYear - era * 400
    let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
    let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
    let days = era * 146_097 + dayOfEra - 719_468
    return (((days * 24 + hour) * 60 + minute) * 60 + second) * 1_000 + millisecond
}
