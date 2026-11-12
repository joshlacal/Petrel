import Crypto
import Foundation
import PetrelCrypto
import P256K
import Testing

/// One test per defect the 2026-11 conformance audit found in code that
/// already existed. Each uses only Petrel API that predates the fix: built
/// against the revision before the fixes, every test here fails. (That
/// revision names the libsecp256k1 wrapper module `secp256k1`, not `P256K`.)
@Suite("Audit regressions")
struct AuditRegressionTests {
    /// floor(n / 2) for P-256. The implementation once had `d6` where this
    /// has `e5`, which made it reject (and, when signing, flip to high-S)
    /// low-S values in the gap between the two.
    static let p256HalfOrder = Data([
        0x7f, 0xff, 0xff, 0xff, 0x80, 0x00, 0x00, 0x00,
        0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xde, 0x73, 0x7d, 0x56, 0xd3, 0x8b, 0xcf, 0x42,
        0x79, 0xdc, 0xe5, 0x61, 0x7e, 0x31, 0x92, 0xa8,
    ])

    @Test("P-256 low-S threshold is floor(n / 2), not a few bytes below it")
    func p256HalfOrderIsExact() throws {
        let r = Data(repeating: 0, count: 31) + Data([1])
        let atBoundary = r + Self.p256HalfOrder

        #expect(P256WireSignature.isCanonicalLowS(atBoundary))
        _ = try P256WireSignature.decodeCanonical(atBoundary)
        // A signer must leave an already-low S alone.
        #expect(try P256WireSignature.canonicalize(atBoundary) == atBoundary)

        // Just inside the old, wrong gap: still low-S.
        var insideGap = Self.p256HalfOrder
        insideGap[insideGap.endIndex - 1] -= 1
        #expect(P256WireSignature.isCanonicalLowS(r + insideGap))
        #expect(try P256WireSignature.canonicalize(r + insideGap) == r + insideGap)
    }

    @Test("Base58BTC maps each leading zero byte to exactly one '1'")
    func base58AllZeroInput() throws {
        #expect(Base58BTC.encode(Data([0])) == "1")
        #expect(Base58BTC.encode(Data([0, 0])) == "11")
        #expect(try Base58BTC.decode("1") == Data([0]))
        #expect(try Base58BTC.decode("11") == Data([0, 0]))
    }

    @Test("Legacy uncompressed K-256 key with an off-curve Y is rejected")
    func legacyK256ChecksY() throws {
        let uncompressed = try P256K.Signing.PrivateKey(format: .uncompressed).publicKey.dataRepresentation
        #expect(uncompressed.count == 65)
        _ = try PLCDIDKeyCodec.decodeLegacyMultibase("z" + Base58BTC.encode(uncompressed), curve: .secp256k1)

        var corrupted = uncompressed
        corrupted[corrupted.endIndex - 1] ^= 0x01
        #expect(throws: PetrelCryptoError.self) {
            _ = try PLCDIDKeyCodec.decodeLegacyMultibase("z" + Base58BTC.encode(corrupted), curve: .secp256k1)
        }
    }

    @Test("A K-256 key given as an uncompressed point still encodes a decodable did:key")
    func uncompressedK256EncodesCanonically() throws {
        let privateKey = try P256K.Signing.PrivateKey(format: .uncompressed)
        let uncompressed = privateKey.publicKey.dataRepresentation
        let compressed = try P256K.Signing.PrivateKey(
            dataRepresentation: privateKey.dataRepresentation, format: .compressed
        ).publicKey.dataRepresentation

        let key = PLCDIDVerificationKey.secp256k1(uncompressed)
        #expect(key.didKeyBytes.count == 35)
        #expect(key.didKey == PLCDIDVerificationKey.secp256k1(compressed).didKey)
        _ = try PLCDIDKeyCodec.decode(key.didKey)
    }

    @Test("A K-256 verification key has one identity across encodings")
    func k256IdentityIsNormalized() throws {
        let privateKey = try P256K.Signing.PrivateKey(format: .uncompressed)
        let uncompressed = privateKey.publicKey.dataRepresentation
        let compressed = try P256K.Signing.PrivateKey(
            dataRepresentation: privateKey.dataRepresentation, format: .compressed
        ).publicKey.dataRepresentation

        let fromUncompressed = try ATProtoJWTVerificationKey(secp256k1PublicKey: uncompressed)
        let fromCompressed = try ATProtoJWTVerificationKey(secp256k1PublicKey: compressed)
        #expect(fromUncompressed == fromCompressed)
        #expect(fromUncompressed.recoveryVerifierIdentity == fromCompressed.recoveryVerifierIdentity)
    }

    @Test("A service JWT with a high-S signature verifies, as the specification allows")
    func serviceJWTAcceptsHighS() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let key = P256.Signing.PrivateKey()
        let token = try ServiceJWT.mint(
            issuer: "did:plc:abcdefghijklmnopqrstuvwx",
            audience: "did:web:api.bsky.app",
            method: "app.bsky.actor.getProfile",
            eventID: "audit-high-s",
            key: key,
            now: now
        )
        let parts = token.split(separator: ".").map(String.init)
        let signature = try JWTBase64URL.decode(parts[2])
        let highS = try highSTwinOfP256(signature)
        let highSToken = "\(parts[0]).\(parts[1]).\(JWTBase64URL.encode(highS))"

        let claims = try ServiceJWT.verify(highSToken, publicKey: ATProtoJWTVerificationKey.p256(key.publicKey), now: now)
        #expect(claims.jti == "audit-high-s")
    }

    /// `(r, n - s)` using only `floor(n / 2)`: n - s == 2 * half + 1 - s.
    private func highSTwinOfP256(_ signature: Data) throws -> Data {
        let half = Array(Self.p256HalfOrder)
        let s = Array(signature.suffix(32))
        // order = 2 * half + 1
        var order = [UInt8](repeating: 0, count: 32)
        var carry = 1
        for index in stride(from: 31, through: 0, by: -1) {
            let value = Int(half[index]) * 2 + carry
            order[index] = UInt8(value & 0xff)
            carry = value >> 8
        }
        var result = [UInt8](repeating: 0, count: 32)
        var borrow = 0
        for index in stride(from: 31, through: 0, by: -1) {
            var value = Int(order[index]) - Int(s[index]) - borrow
            if value < 0 {
                value += 256
                borrow = 1
            } else {
                borrow = 0
            }
            result[index] = UInt8(value)
        }
        return Data(signature.prefix(32)) + Data(result)
    }
}
