import Crypto
import Foundation
@testable import PetrelCrypto
import Testing

@Suite("November 12 Space MAC")
struct SpaceMACTests {
    func bytes(_ hex: String) -> Data {
        Data(stride(from: 0, to: hex.count, by: 2).map { offset in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            return UInt8(hex[start ..< hex.index(start, offsetBy: 2)], radix: 16)!
        })
    }

    @Test("HPKE secret export matches the RFC 9180 export-only P-256 vector")
    func rfc9180ExportOnly() throws {
        // The keys are from RFC 9180's export-only DHKEM(P-256, HKDF-SHA256)
        // vector. The expected export uses this protocol's "atproto-mac" info
        // and an empty exporter context, as independently computed in Go.
        let sender = try P256.KeyAgreement.PrivateKey(
            rawRepresentation: bytes("2f18b059576a0ec5a17121c0fe7ec8f00ea86f7b046fa3889ac8f21f89dbd484")
        )
        let author = try P256.KeyAgreement.PrivateKey(
            rawRepresentation: bytes("62c3868357a464f8461d03aa0182c7cebcde841036aea7230ddc7339f1088346")
        )
        let expectedSender = try P256.Signing.PublicKey(
            x963Representation: bytes("04d804370b7e24b94749eb1dc8df6d4d4a5d75f9effad01739ebcad5c54a40d57aaa8b4190fc124dbde2e4f1e1d1b012a3bc4038157dc29b55533a932306d8d38d")
        )
        let expectedSecret = bytes("2060e0558d1b34c10086bc137f849bb79ba59fcdc30544418e35c9cd301f0d0d")
        let keyShare = P256DIDKey(publicKey: expectedSender).value
        let authorSigningKey = try P256.Signing.PublicKey(
            compressedRepresentation: author.publicKey.compressedRepresentation
        )

        let encapsulation = try SpaceMAC.encapsulate(
            authorKey: P256DIDKey(publicKey: authorSigningKey).value,
            ephemeralKey: sender
        )
        #expect(encapsulation.keyShare == keyShare)
        #expect(encapsulation.sharedSecret == expectedSecret)
        #expect(try SpaceMAC.decapsulate(privateKey: author, keyShare: keyShare) == expectedSecret)
    }

    @Test("Every encapsulation uses fresh keys and binds recipient")
    func freshKeys() throws {
        let recipient = P256.KeyAgreement.PrivateKey()
        let signingPublic = try P256.Signing.PublicKey(compressedRepresentation: recipient.publicKey.compressedRepresentation)
        let key = P256DIDKey(publicKey: signingPublic).value
        let first = try SpaceMAC.encapsulate(authorKey: key)
        let second = try SpaceMAC.encapsulate(authorKey: key)
        #expect(first.keyShare != second.keyShare)
        #expect(first.sharedSecret != second.sharedSecret)
        #expect(try SpaceMAC.decapsulate(privateKey: recipient, keyShare: first.keyShare) == first.sharedSecret)
        #expect(try SpaceMAC.decapsulate(privateKey: P256.KeyAgreement.PrivateKey(), keyShare: first.keyShare) != first.sharedSecret)
        #expect(throws: (any Error).self) { try SpaceMAC.encapsulate(authorKey: "did:key:zInvalid") }
    }
}
