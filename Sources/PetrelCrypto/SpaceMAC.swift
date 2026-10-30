import Crypto
import Foundation

/// October 22 Spaces response authentication (DHKEM P-256 / HKDF-SHA256).
/// Secrets belong to one HTTP request, independently of credential binding keys.
public enum SpaceMAC {
    public enum Failure: Error, Sendable, Equatable {
        case invalidKey
        case invalidContext
        case mismatch
    }

    public struct Encapsulation: Sendable {
        public let keyShare: String
        public let sharedSecret: Data
    }

    public static func encapsulate(authorKey: String) throws -> Encapsulation {
        try encapsulate(authorKey: authorKey, ephemeralKey: P256.KeyAgreement.PrivateKey())
    }

    /// Deterministic entry point for independent vectors; production callers use the fresh-key overload.
    package static func encapsulate(
        authorKey: String, ephemeralKey: P256.KeyAgreement.PrivateKey
    ) throws -> Encapsulation {
        let author = try agreementKey(authorKey)
        let signingKey = try P256.Signing.PublicKey(compressedRepresentation: ephemeralKey.publicKey.compressedRepresentation)
        return try Encapsulation(
            keyShare: P256DIDKey(publicKey: signingKey).value,
            sharedSecret: derive(
                privateKey: ephemeralKey, publicKey: author,
                sender: ephemeralKey.publicKey, recipient: author
            )
        )
    }

    public static func decapsulate(privateKey: P256.KeyAgreement.PrivateKey, keyShare: String) throws -> Data {
        let sender = try agreementKey(keyShare)
        return try derive(privateKey: privateKey, publicKey: sender, sender: sender, recipient: privateKey.publicKey)
    }

    private static func agreementKey(_ didKey: String) throws -> P256.KeyAgreement.PublicKey {
        let key = try P256DIDKey(didKey).publicKey
        return try P256.KeyAgreement.PublicKey(compressedRepresentation: key.compressedRepresentation)
    }

    private static func derive(
        privateKey: P256.KeyAgreement.PrivateKey,
        publicKey: P256.KeyAgreement.PublicKey,
        sender: P256.KeyAgreement.PublicKey,
        recipient: P256.KeyAgreement.PublicKey
    ) throws -> Data {
        let dh = try privateKey.sharedSecretFromKeyAgreement(with: publicKey)
        let prefix = Data("HPKE-v1KEM".utf8) + Data([0, 0x10])
        let input = prefix + Data("eae_prk".utf8) + dh.withUnsafeBytes { Data($0) }
        let info = Data([0, 32]) + prefix + Data("shared_secret".utf8)
            + sender.x963Representation + recipient.x963Representation
        let secret = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: input), salt: Data(), info: info, outputByteCount: 32
        )
        return secret.withUnsafeBytes { Data($0) }
    }

    public static func commit(sharedSecret: Data, space: String, repo: String, rev: String, data: Data) throws -> Data {
        guard data.count == 32 else { throw Failure.invalidContext }
        let context = try Data("atproto-space-repo-v1".utf8) + field(space) + field(repo) + field(rev) + data
        return try authenticate(context, sharedSecret: sharedSecret)
    }

    public static func record(sharedSecret: Data, uri: String, cid: Data) throws -> Data {
        guard !cid.isEmpty else { throw Failure.invalidContext }
        return try authenticate(Data("atproto-space-record-v1".utf8) + field(uri) + cid, sharedSecret: sharedSecret)
    }

    public static func verify(mac: Data, expected: Data) throws {
        guard mac.count == 32, expected.count == 32 else { throw Failure.mismatch }
        // Fixed-length comparison; never short-circuit on a mismatching byte.
        var difference: UInt8 = 0
        for (left, right) in zip(mac, expected) {
            difference |= left ^ right
        }
        guard difference == 0 else { throw Failure.mismatch }
    }

    private static func field(_ string: String) throws -> Data {
        let bytes = Data(string.utf8)
        guard bytes.count <= Int(UInt16.max) else { throw Failure.invalidContext }
        return Data([UInt8(bytes.count >> 8), UInt8(bytes.count & 0xFF)]) + bytes
    }

    private static func authenticate(_ context: Data, sharedSecret: Data) throws -> Data {
        guard sharedSecret.count == 32 else { throw Failure.invalidKey }
        return Data(HMAC<SHA256>.authenticationCode(for: context, using: SymmetricKey(data: sharedSecret)))
    }
}
