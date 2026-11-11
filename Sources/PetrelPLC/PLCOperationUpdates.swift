import Foundation
import PetrelCrypto

/// The editable state of an identity while an update is being prepared.
///
/// ``PLCOperationCodec/update(after:_:)`` hands a draft holding the current
/// state to a closure; whatever the closure leaves in it becomes the next
/// operation. Every field of an update operation is a full replacement, so
/// fields the closure does not touch are carried over unchanged.
public struct PLCOperationDraft: Sendable, Equatable {
    /// Priority-ordered rotation keys, as `did:key` strings.
    public var rotationKeys: [String]
    /// Verification method id (no `#`) to `did:key`.
    public var verificationMethods: [String: String]
    /// Priority-ordered aliases.
    public var alsoKnownAs: [String]
    /// Service id (no `#`) to service.
    public var services: [String: PLCService]

    /// Creates a draft from explicit values.
    public init(
        rotationKeys: [String],
        verificationMethods: [String: String],
        alsoKnownAs: [String],
        services: [String: PLCService]
    ) {
        self.rotationKeys = rotationKeys
        self.verificationMethods = verificationMethods
        self.alsoKnownAs = alsoKnownAs
        self.services = services
    }

    /// Starts from an identity's current state.
    public init(_ data: PLCDocumentData) {
        self.init(
            rotationKeys: data.rotationKeys,
            verificationMethods: data.verificationMethods,
            alsoKnownAs: data.alsoKnownAs,
            services: data.services
        )
    }

    /// Sets the atproto handle: replaces the first `at://` alias, or puts
    /// the handle first when there is none. Other aliases are kept.
    ///
    /// - Parameter handle: With or without `at://`; validated and lower-cased.
    public mutating func setHandle(_ handle: String) throws {
        let uri = try PLCATProfile.handleURI(handle)
        if let index = alsoKnownAs.firstIndex(where: { $0.hasPrefix("at://") }) {
            alsoKnownAs[index] = uri
        } else {
            alsoKnownAs.insert(uri, at: 0)
        }
    }

    /// Sets the `atproto_pds` service. Other services are kept.
    ///
    /// - Parameter endpoint: See ``PLCATProfile/pdsEndpoint(_:)``.
    public mutating func setPDS(endpoint: String) throws {
        services[PLCATProfile.pdsServiceID] = try PLCService(
            type: PLCATProfile.pdsServiceType,
            endpoint: PLCATProfile.pdsEndpoint(endpoint)
        )
    }

    /// Sets the `atproto` verification method, the repository signing key.
    /// Other verification methods are kept.
    ///
    /// - Parameter signingKey: A P-256 or K-256 `did:key`.
    public mutating func setAtprotoKey(_ signingKey: String) throws {
        verificationMethods[PLCATProfile.signingKeyID] = try PLCATProfile.signingDIDKey(signingKey)
    }
}

public extension PLCOperationCodec {
    /// Prepares the operation that follows `last`, the counterpart of the
    /// reference library's `createUpdateOp`.
    ///
    /// `prev` is set to the CID of `last`, and the closure edits a draft of
    /// the state `last` established. A legacy `create` operation is
    /// presented to the closure in the modern shape.
    ///
    /// `last` is normally the newest non-nullified entry of a verified audit
    /// log. For a recovery, pass the entry to fork from instead: the result,
    /// signed by a higher-authority rotation key within 72 hours, nullifies
    /// everything after that entry.
    ///
    /// - Throws: ``PetrelPLCError/malformed(_:)`` if `last` is a tombstone or
    ///   the edited draft breaks a write rule.
    static func update(
        after last: PLCSignedOperation,
        _ mutate: (inout PLCOperationDraft) throws -> Void
    ) throws -> PLCUnsignedRegularOperation {
        guard let current = last.documentData(did: "") else {
            throw PetrelPLCError.malformed("a tombstoned PLC identity cannot be updated")
        }
        var draft = PLCOperationDraft(current)
        try mutate(&draft)
        return try PLCUnsignedRegularOperation(
            rotationKeys: draft.rotationKeys,
            verificationMethods: draft.verificationMethods,
            alsoKnownAs: draft.alsoKnownAs,
            services: draft.services,
            prev: last.cid.string
        )
    }

    /// Prepares an update that changes the atproto handle.
    static func updateHandle(
        after last: PLCSignedOperation,
        handle: String
    ) throws -> PLCUnsignedRegularOperation {
        try update(after: last) { try $0.setHandle(handle) }
    }

    /// Prepares an update that moves the account to another PDS.
    static func updatePDS(
        after last: PLCSignedOperation,
        endpoint: String
    ) throws -> PLCUnsignedRegularOperation {
        try update(after: last) { try $0.setPDS(endpoint: endpoint) }
    }

    /// Prepares an update that replaces the atproto repository signing key.
    static func updateAtprotoKey(
        after last: PLCSignedOperation,
        signingKey: String
    ) throws -> PLCUnsignedRegularOperation {
        try update(after: last) { try $0.setAtprotoKey(signingKey) }
    }

    /// Prepares an update that replaces the rotation keys.
    ///
    /// The update itself must still be signed by one of the *current*
    /// rotation keys.
    ///
    /// - Parameters:
    ///   - last: The operation to follow.
    ///   - rotationKeys: 1–5 distinct P-256 or K-256 `did:key` values in
    ///     descending authority.
    static func updateRotationKeys(
        after last: PLCSignedOperation,
        rotationKeys: [String]
    ) throws -> PLCUnsignedRegularOperation {
        try update(after: last) { $0.rotationKeys = rotationKeys }
    }

    /// Prepares the tombstone that deactivates the identity after `last`.
    ///
    /// - Throws: ``PetrelPLCError/malformed(_:)`` if `last` is already a
    ///   tombstone.
    static func tombstone(
        after last: PLCSignedOperation
    ) throws -> PLCUnsignedTombstoneOperation {
        guard !last.isTombstone else {
            throw PetrelPLCError.malformed("a tombstoned PLC identity cannot be updated")
        }
        return try PLCUnsignedTombstoneOperation(prev: last.cid.string)
    }
}
