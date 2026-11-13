import Crypto
import Foundation

/// Spaces response authentication with HPKE secret export
/// (DHKEM P-256 / HKDF-SHA256 / Export-only).
///
/// Secrets belong to one HTTP request, independently of credential binding keys.
public enum SpaceMAC {
    private static let hashByteCount = 32

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
        let dh = try privateKey.sharedSecretFromKeyAgreement(with: publicKey).withUnsafeBytes { Data($0) }
        let kemID = concatenating(Data("KEM".utf8), uint16(0x0010))
        let suiteID = concatenating(
            Data("HPKE".utf8), uint16(0x0010), uint16(0x0001), uint16(0xFFFF)
        )

        let eaePRK = labeledExtract(id: kemID, salt: Data(), label: "eae_prk", input: dh)
        let kemContext = concatenating(sender.x963Representation, recipient.x963Representation)
        let kemSecret = try labeledExpand(
            id: kemID, pseudorandomKey: eaePRK, label: "shared_secret",
            info: kemContext, outputByteCount: 32
        )

        let pskIDHash = labeledExtract(id: suiteID, salt: Data(), label: "psk_id_hash", input: Data())
        let infoHash = labeledExtract(
            id: suiteID, salt: Data(), label: "info_hash", input: Data("atproto-mac".utf8)
        )
        let keyScheduleContext = concatenating(Data([0]), pskIDHash, infoHash)
        let secret = labeledExtract(id: suiteID, salt: kemSecret, label: "secret", input: Data())
        let exporterSecret = try labeledExpand(
            id: suiteID, pseudorandomKey: secret, label: "exp",
            info: keyScheduleContext, outputByteCount: 32
        )
        return try labeledExpand(
            id: suiteID, pseudorandomKey: exporterSecret, label: "sec",
            info: Data(), outputByteCount: 32
        )
    }

    package static func authenticationCode(for message: Data, sharedSecret: Data) throws -> Data {
        guard sharedSecret.count == 32 else { throw Failure.invalidKey }
        return Data(HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: sharedSecret)))
    }

    package static func verify(authenticationCode: Data, message: Data, sharedSecret: Data) throws {
        guard authenticationCode.count == 32 else { throw Failure.mismatch }
        let expected = try self.authenticationCode(for: message, sharedSecret: sharedSecret)
        var difference: UInt8 = 0
        for (left, right) in zip(authenticationCode, expected) {
            difference |= left ^ right
        }
        guard difference == 0 else { throw Failure.mismatch }
    }

    private static func labeledExtract(id: Data, salt: Data, label: String, input: Data) -> Data {
        hkdfExtract(
            salt: salt,
            input: concatenating(Data("HPKE-v1".utf8), id, Data(label.utf8), input)
        )
    }

    private static func labeledExpand(
        id: Data,
        pseudorandomKey: Data,
        label: String,
        info: Data,
        outputByteCount: Int
    ) throws -> Data {
        guard (0 ... Int(UInt16.max)).contains(outputByteCount) else { throw Failure.invalidContext }
        return try hkdfExpand(
            pseudorandomKey: pseudorandomKey,
            info: concatenating(
                uint16(UInt16(outputByteCount)), Data("HPKE-v1".utf8), id, Data(label.utf8), info
            ),
            outputByteCount: outputByteCount
        )
    }

    private static func hkdfExtract(salt: Data, input: Data) -> Data {
        let key = SymmetricKey(data: salt.isEmpty ? Data(repeating: 0, count: hashByteCount) : salt)
        return Data(HMAC<SHA256>.authenticationCode(for: input, using: key))
    }

    private static func hkdfExpand(
        pseudorandomKey: Data,
        info: Data,
        outputByteCount: Int
    ) throws -> Data {
        guard outputByteCount <= 255 * hashByteCount else { throw Failure.invalidContext }
        guard outputByteCount > 0 else { return Data() }

        let key = SymmetricKey(data: pseudorandomKey)
        var output = Data()
        output.reserveCapacity(outputByteCount)
        var previous = Data()
        for counter in UInt8(1) ... UInt8((outputByteCount + hashByteCount - 1) / hashByteCount) {
            let input = concatenating(previous, info, Data([counter]))
            previous = Data(HMAC<SHA256>.authenticationCode(for: input, using: key))
            output.append(previous.prefix(outputByteCount - output.count))
        }
        return output
    }

    private static func uint16(_ value: UInt16) -> Data {
        Data([UInt8(value >> 8), UInt8(value & 0xFF)])
    }

    private static func concatenating(_ values: Data...) -> Data {
        var output = Data(capacity: values.reduce(0) { $0 + $1.count })
        for value in values {
            output.append(value)
        }
        return output
    }
}
