import Foundation
import PetrelCrypto

public extension PLCDirectoryClient {
    /// Registers a new atproto identity: builds the genesis operation, signs
    /// it, derives the DID and submits. The counterpart of the reference
    /// client's `createDid`.
    ///
    /// - Parameters:
    ///   - handle: The account handle.
    ///   - signingKey: The repository signing key, a P-256 or K-256 `did:key`.
    ///   - rotationKeys: 1–5 distinct rotation keys in descending authority.
    ///   - pdsEndpoint: The account's PDS URL.
    ///   - signer: The private half of one of `rotationKeys`.
    /// - Returns: The new DID and the operation that created it.
    @discardableResult
    func createDID(
        handle: String,
        signingKey: String,
        rotationKeys: [String],
        pdsEndpoint: String,
        signer: any ATProtoSigner
    ) async throws -> (did: String, operation: PLCSignedOperation) {
        let unsigned = try PLCATProfile.genesisOperation(
            handle: handle,
            signingKey: signingKey,
            rotationKeys: rotationKeys,
            pdsEndpoint: pdsEndpoint
        )
        try Self.requireRotationKey(signer, among: rotationKeys)
        let operation = try await PLCOperationCodec.sign(.regular(unsigned), with: signer)
        // Proves the signer really is one of the rotation keys before the
        // DID is derived from an operation the directory would refuse.
        let did = try PLCOperationCodec.genesisDID(for: operation)
        try PLCOperationCodec.verifyGenesis(operation, expectedDID: did)
        try await submit(did: did, operation: operation)
        return (did, operation)
    }

    /// Updates an identity: reads and verifies its audit log, lets `mutate`
    /// edit the current state, then signs and submits the result. The
    /// counterpart of the reference client's `updateData`.
    ///
    /// The previous operation comes from the *verified* log, so the update
    /// is never built on state the directory merely asserted.
    ///
    /// - Parameters:
    ///   - did: The identity to update.
    ///   - signer: The private half of one of the identity's current
    ///     rotation keys.
    ///   - mutate: Edits the draft. Fields left alone are carried over.
    /// - Returns: The operation that was submitted.
    /// - Throws: ``PetrelPLCError/tombstoned(did:)`` for a deactivated
    ///   identity; ``PetrelPLCError/unauthorized(_:)`` when `signer` exposes
    ///   a public key that is not a current rotation key.
    @discardableResult
    func update(
        did: String,
        signer: any ATProtoSigner,
        _ mutate: @Sendable (inout PLCOperationDraft) throws -> Void
    ) async throws -> PLCSignedOperation {
        let head = try await currentOperation(did: did, signer: signer)
        let unsigned = try PLCOperationCodec.update(after: head, mutate)
        let operation = try await PLCOperationCodec.sign(.regular(unsigned), with: signer)
        try await submit(did: did, operation: operation)
        return operation
    }

    /// Changes the identity's atproto handle. Other aliases are kept.
    @discardableResult
    func updateHandle(
        did: String,
        signer: any ATProtoSigner,
        handle: String
    ) async throws -> PLCSignedOperation {
        try await update(did: did, signer: signer) { try $0.setHandle(handle) }
    }

    /// Points the identity at another PDS. Other services are kept.
    @discardableResult
    func updatePDS(
        did: String,
        signer: any ATProtoSigner,
        endpoint: String
    ) async throws -> PLCSignedOperation {
        try await update(did: did, signer: signer) { try $0.setPDS(endpoint: endpoint) }
    }

    /// Replaces the identity's atproto repository signing key.
    @discardableResult
    func updateAtprotoKey(
        did: String,
        signer: any ATProtoSigner,
        signingKey: String
    ) async throws -> PLCSignedOperation {
        try await update(did: did, signer: signer) { try $0.setAtprotoKey(signingKey) }
    }

    /// Replaces the identity's rotation keys.
    ///
    /// `signer` must be one of the *current* rotation keys. For 72 hours
    /// after this operation, a current key of higher authority than `signer`
    /// can still nullify it.
    ///
    /// - Parameters:
    ///   - did: The identity to update.
    ///   - signer: The private half of one of the current rotation keys.
    ///   - rotationKeys: 1–5 distinct P-256 or K-256 `did:key` values in
    ///     descending authority.
    @discardableResult
    func updateRotationKeys(
        did: String,
        signer: any ATProtoSigner,
        rotationKeys: [String]
    ) async throws -> PLCSignedOperation {
        try await update(did: did, signer: signer) { $0.rotationKeys = rotationKeys }
    }

    /// Deactivates the identity by submitting a tombstone. A rotation key of
    /// higher authority than `signer` can undo this for 72 hours; after
    /// that it is permanent.
    @discardableResult
    func tombstone(
        did: String,
        signer: any ATProtoSigner
    ) async throws -> PLCSignedOperation {
        let head = try await currentOperation(did: did, signer: signer)
        let unsigned = try PLCOperationCodec.tombstone(after: head)
        let operation = try await PLCOperationCodec.sign(.tombstone(unsigned), with: signer)
        try await submit(did: did, operation: operation)
        return operation
    }

    /// The newest valid operation of the verified audit log, after checking
    /// that it can be followed and that `signer` is entitled to follow it.
    private func currentOperation(
        did: String,
        signer: any ATProtoSigner
    ) async throws -> PLCSignedOperation {
        let head = try await fetchVerifiedAuditLog(did: did).head.operation
        guard let rotationKeys = head.rotationKeys else {
            throw PetrelPLCError.tombstoned(did: did)
        }
        try Self.requireRotationKey(signer, among: rotationKeys)
        return head
    }

    /// Refuses, before anything is signed, a signer whose public key is
    /// known and is not among the keys allowed to sign. A signer that does
    /// not expose its public key cannot be checked here; the directory will
    /// refuse its operation instead.
    private static func requireRotationKey(
        _ signer: any ATProtoSigner,
        among rotationKeys: [String]
    ) throws {
        guard let keypair = signer as? any ATProtoKeypair else { return }
        guard rotationKeys.contains(keypair.didKey) else {
            throw PetrelPLCError.unauthorized(
                "PLC signer \(keypair.didKey) is not one of the identity's rotation keys"
            )
        }
    }
}
