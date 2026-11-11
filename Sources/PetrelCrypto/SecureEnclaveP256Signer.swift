#if canImport(CryptoKit) && canImport(Security) && (os(iOS) || os(macOS) || os(visionOS))
    import CryptoKit
    import Foundation
    import Security

    /// A P-256 signing key that lives inside the Secure Enclave.
    ///
    /// The private scalar is generated in the enclave and cannot be
    /// exported; this type is therefore an ``ATProtoKeypair`` but not an
    /// ``ATProtoExportableKeypair``. What you persist is
    /// ``dataRepresentation`` — an opaque blob only this device's enclave
    /// can turn back into a key.
    ///
    /// The enclave returns whichever S value its ECDSA produced, so
    /// ``sign(_:)`` folds it to low-S before returning, as AT Protocol
    /// requires.
    ///
    /// ```swift
    /// guard SecureEnclaveP256Signer.isAvailable else { return }
    /// let signer = try SecureEnclaveP256Signer.generate()
    /// keychain.save(signer.dataRepresentation)
    /// let signature = try signer.sign(commitBytes)
    /// ```
    public struct SecureEnclaveP256Signer: ATProtoKeypair, CustomStringConvertible {
        /// The public half of the key.
        public let publicKey: ATProtoPublicKey

        /// The enclave-wrapped key blob. Not secret key material, but only
        /// usable on the device that created it. Store it in the keychain.
        public let dataRepresentation: Data

        /// Whether this device has a Secure Enclave. `false` in the
        /// simulator and on Macs without one.
        public static var isAvailable: Bool { SecureEnclave.isAvailable }

        /// Generates a new key inside the Secure Enclave.
        ///
        /// - Parameter accessControl: Keychain access control for the key,
        ///   for example to require biometry for each signature. `nil` uses
        ///   CryptoKit's default (usable while the device is unlocked, this
        ///   device only).
        /// - Throws: A CryptoKit error if the enclave is unavailable or
        ///   refuses the request.
        public static func generate(accessControl: SecAccessControl? = nil) throws -> SecureEnclaveP256Signer {
            let key: SecureEnclave.P256.Signing.PrivateKey
            if let accessControl {
                key = try SecureEnclave.P256.Signing.PrivateKey(accessControl: accessControl)
            } else {
                key = try SecureEnclave.P256.Signing.PrivateKey()
            }
            return SecureEnclaveP256Signer(key)
        }

        /// Restores a key from a blob previously read from
        /// ``dataRepresentation``.
        ///
        /// - Throws: A CryptoKit error if the blob was not created by this
        ///   device's enclave.
        public init(dataRepresentation: Data) throws {
            self.init(try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: dataRepresentation))
        }

        /// Wraps an existing CryptoKit Secure Enclave key.
        public init(_ key: SecureEnclave.P256.Signing.PrivateKey) {
            publicKey = ATProtoPublicKey(key.publicKey)
            dataRepresentation = key.dataRepresentation
        }

        /// Signs `SHA-256(message)` in the enclave and returns the 64-byte
        /// compact low-S signature.
        public func sign(_ message: Data) throws -> Data {
            let key = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: dataRepresentation)
            return try ATProtoSignature.canonicalize(
                key.signature(for: message).rawRepresentation,
                curve: .p256
            )
        }

        /// The public `did:key`.
        public var description: String { "SecureEnclaveP256Signer(\(publicKey.didKey))" }
    }
#endif
