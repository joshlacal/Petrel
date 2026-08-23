import Crypto
import Foundation
@testable import PetrelCrypto
import secp256k1
import XCTest

final class PetrelCryptoTests: XCTestCase {
    private let privateKey = try! P256.Signing.PrivateKey(rawRepresentation: Data(repeating: 7, count: 32))
    private let rotationKey = try! P256.Signing.PrivateKey(rawRepresentation: Data(repeating: 9, count: 32))

    func testP256WireSignaturesNormalizeAndRejectMalleableHighSValues() throws {
        let key = P256.Signing.PrivateKey()
        let message = Data("canonical P-256 wire signature".utf8)
        let canonical = try P256WireSignature.sign(message, using: key)
        XCTAssertTrue(P256WireSignature.isCanonicalLowS(canonical))

        let highS = highSVariant(of: canonical)
        let highSSignature = try P256.Signing.ECDSASignature(rawRepresentation: highS)
        XCTAssertTrue(key.publicKey.isValidSignature(highSSignature, for: message))
        XCTAssertThrowsError(try P256WireSignature.decodeCanonical(highS))
        XCTAssertEqual(try P256WireSignature.canonicalize(highS), canonical)
    }

    // JOSE defines no canonical (r, s) encoding, so the malleability-tolerant
    // decoder must accept the high-S variant that `decodeCanonical` rejects —
    // while still enforcing structural scalar validation.
    func testMalleabilityTolerantDecodeAcceptsHighSButStillValidatesScalars() throws {
        let key = P256.Signing.PrivateKey()
        let message = Data("JOSE ES256 has no canonical encoding".utf8)
        let canonical = try P256WireSignature.sign(message, using: key)
        let highS = highSVariant(of: canonical)

        // Both encodings decode, and both verify against the same key.
        for raw in [canonical, highS] {
            let decoded = try P256WireSignature.decodeMalleabilityTolerant(raw)
            XCTAssertTrue(key.publicKey.isValidSignature(decoded, for: message))
        }
        // The strict decoder still rejects high-S, so AT Protocol's own
        // signature suites keep their canonical-encoding guarantee.
        XCTAssertThrowsError(try P256WireSignature.decodeCanonical(highS))

        // Structural validation is not weakened.
        XCTAssertThrowsError(
            try P256WireSignature.decodeMalleabilityTolerant(Data(repeating: 0, count: 63)))
        XCTAssertThrowsError(
            try P256WireSignature.decodeMalleabilityTolerant(Data(repeating: 0, count: 64)))
    }

    func testP256WireSignatureUsesTheExactP256HalfOrderBoundary() {
        let r = Data(repeating: 0, count: 31) + Data([1])
        let halfOrder = Data([
            0x7f, 0xff, 0xff, 0xff, 0x80, 0x00, 0x00, 0x00,
            0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
            0xde, 0x73, 0x7d, 0x56, 0xd3, 0x8b, 0xcf, 0x42,
            0x79, 0xdc, 0xd6, 0x61, 0x7e, 0x31, 0x92, 0xa8,
        ])
        XCTAssertTrue(P256WireSignature.isCanonicalLowS(r + halfOrder))

        var highS = halfOrder
        highS[highS.index(before: highS.endIndex)] += 1
        XCTAssertFalse(P256WireSignature.isCanonicalLowS(r + highS))
    }

    func testP256DIDKeyMatchesPinnedTypeScriptCompressedGoldenAndRoundTrips() throws {
        let encoded = P256DIDKey(publicKey: privateKey.publicKey)
        XCTAssertEqual(
            encoded.value,
            "did:key:zDnaejgmAHMLkBPMBWnkBxyGxpXx8LgE4WJAYDhwZzyoRAddF"
        )
        XCTAssertEqual(try P256DIDKey(encoded.value).publicKey.x963Representation, privateKey.publicKey.x963Representation)
        XCTAssertEqual(try P256DIDKey(encoded.value).value, encoded.value)
    }

    func testP256DIDKeyRejectsWrongCodecUncompressedPointAndNonCanonicalBase58() throws {
        let valid = P256DIDKey(publicKey: privateKey.publicKey).value
        for malformed in [
            valid.replacingOccurrences(of: "did:key:z", with: "did:key:x"),
            "did:key:z\(String(valid.dropFirst("did:key:z".count)).uppercased())",
            "did:key:z1\(valid.dropFirst("did:key:z".count))",
            "did:key:z6MkiTBz1yXLP7QKgQDeq5DgxdBdXKvg8u3Yu1B7S5K6M2HTh",
            "did:key:z4oJ8aP4p91UJupm9qqYqdmqYucG7LvoPBydLL1FY5JhmF6gqCeLRyBYB7vM7GXKPyhujKbVUqZh9gQ5rvuz49hchqusY",
        ] {
            XCTAssertThrowsError(try P256DIDKey(malformed), malformed)
        }
    }

    func testSecp256k1DIDKeyCodecAcceptsPinnedTypeScriptFormOnly() throws {
        let value = "did:key:zQ3shqwJEJyMBsBXCWyCBpUBMqxcon9oHB7mCvx4sSpMdLJwc"
        let key = try PLCDIDKeyCodec.decode(value)
        guard case let .secp256k1(bytes) = key else {
            return XCTFail("expected secp256k1 key")
        }
        XCTAssertEqual(bytes.count, 33)
        XCTAssertEqual(bytes.first, 0x03)
        XCTAssertTrue(PLCDIDKeyCodec.isCanonical(value))
        XCTAssertThrowsError(try PLCDIDKeyCodec.decode(
            value.replacingOccurrences(of: "zQ3s", with: "zDna")
        ))
    }

    func testLegacyMultibaseDecoding() throws {
        // P-256 legacy multibase (compressed and uncompressed)
        let p256Compressed = "zxdM8dSstjrpZaRUwBmDvjGXweKuEMVN95A9oJBFjkWMh"
        let p256Key = try PLCDIDKeyCodec.decodeLegacyMultibase(p256Compressed, curve: .p256)
        guard case let .p256(pub) = p256Key else {
            return XCTFail("expected P-256 key")
        }
        XCTAssertEqual(pub.compressedRepresentation.count, 33)

        // K-256 legacy multibase
        let k256Multibase = "z25z9DTpsiYYJKGsWmSPJK2NFN8PcJtZig12K59UgW7q5t"
        let k256Key = try PLCDIDKeyCodec.decodeLegacyMultibase(k256Multibase, curve: .secp256k1)
        guard case let .secp256k1(kBytes) = k256Key else {
            return XCTFail("expected secp256k1 key")
        }
        XCTAssertEqual(kBytes.count, 33)
    }

    func testES256AndES256KVerification() throws {
        let p256Key = P256.Signing.PrivateKey()
        let msg = Data("hello atproto".utf8)
        let sig = try P256WireSignature.sign(msg, using: p256Key)

        let verifier = ATProtoJWTVerificationKey.p256(p256Key.publicKey)
        XCTAssertTrue(try verifier.verify(signature: sig, signingInput: msg, algorithm: "ES256"))

        // Algorithm mismatch fails
        XCTAssertThrowsError(try verifier.verify(signature: sig, signingInput: msg, algorithm: "ES256K"))

        // secp256k1 key verification
        let secpKey = try secp256k1.Signing.PrivateKey()
        let secpPubBytes = secpKey.publicKey.dataRepresentation
        let secpVerifier = try ATProtoJWTVerificationKey(secp256k1PublicKey: secpPubBytes)

        let compactSig = try secpKey.signature(for: msg)
        // Verify compact representation
        XCTAssertTrue(try secpVerifier.verify(
            signature: compactSig.compactRepresentation,
            signingInput: msg,
            algorithm: "ES256K"
        ))
    }

    func testBase58BTCRoundTrip() throws {
        let testData = Data([0x00, 0x00, 0x01, 0x02, 0x03, 0xff, 0xfe])
        let encoded = Base58BTC.encode(testData)
        let decoded = try Base58BTC.decode(encoded)
        XCTAssertEqual(testData, decoded)
    }

    func testHexCodec() {
        let data = Data([0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef])
        let hex = Hex.encode(data)
        XCTAssertEqual(hex, "0123456789abcdef")
        XCTAssertEqual(Hex.decode(hex), data)
    }
}

private func highSVariant(of canonicalSignature: Data) -> Data {
    precondition(canonicalSignature.count == 64)
    let order: [UInt8] = [
        0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xbc, 0xe6, 0xfa, 0xad, 0xa7, 0x17, 0x9e, 0x84,
        0xf3, 0xb9, 0xca, 0xc2, 0xfc, 0x63, 0x25, 0x51,
    ]
    let lowS = Array(canonicalSignature.suffix(32))
    var highS = Array(repeating: UInt8.zero, count: 32)
    var borrow = 0
    for index in stride(from: 31, through: 0, by: -1) {
        var value = Int(order[index]) - Int(lowS[index]) - borrow
        if value < 0 {
            value += 256
            borrow = 1
        } else {
            borrow = 0
        }
        highS[index] = UInt8(value)
    }
    precondition(borrow == 0)
    return Data(canonicalSignature.prefix(32)) + Data(highS)
}
