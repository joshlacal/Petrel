import Crypto
import Foundation
@testable import PetrelCrypto
import Testing

@Suite("October 22 Space MAC")
struct SpaceMACTests {
    func bytes(_ hex: String) -> Data {
        Data(stride(from: 0, to: hex.count, by: 2).map { offset in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            return UInt8(hex[start ..< hex.index(start, offsetBy: 2)], radix: 16)!
        })
    }

    @Test("DHKEM matches upstream RFC 9180 A.3.1 vector")
    func rfc9180() throws {
        // packages/space/tests/kem.test.ts at ac0c9f15; independently specified RFC vector.
        let sender = try P256.Signing.PublicKey(x963Representation: bytes("04a92719c6195d5085104f469a8b9814d5838ff72b60501e2c4466e5e67b325ac98536d7b61a1af4b78e5b7f951c0900be863c403ce65c9bfcb9382657222d18c4"))
        let recipient = try P256.KeyAgreement.PrivateKey(rawRepresentation: bytes("f3ce7fdae57e1a310d87f1ebbde6f328be0a99cdbcadf4d6589cf29de4b8ffd2"))
        #expect(try SpaceMAC.decapsulate(privateKey: recipient, keyShare: P256DIDKey(publicKey: sender).value) == bytes("c0d26aeab536609a572b07695d933b589dcf363ff9d93c93adea537aeabb8cb8"))
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

    @Test("MAC independently computed with Python hashlib over upstream test inputs")
    func independentMAC() throws {
        let secret = Data(0 ..< 32)
        let space = "at://did:example:space/space/app.bsky.group/test"
        let repo = "did:example:alice"
        let rev = "3kbcq3p7ad400"
        let digest = Data(repeating: 1, count: 32)
        let mac = try SpaceMAC.commit(sharedSecret: secret, space: space, repo: repo, rev: rev, data: digest)
        #expect(mac == bytes("3b38727ea60248c55e0c549faa9a6738a14342eb57d779e6b300784f8b8d6acc"))
        for (wrongSpace, wrongRepo, wrongRev) in [(space + "x", repo, rev), (space, repo + "x", rev), (space, repo, rev + "x")] {
            let wrong = try SpaceMAC.commit(sharedSecret: secret, space: wrongSpace, repo: wrongRepo, rev: wrongRev, data: digest)
            #expect(throws: SpaceMAC.Failure.mismatch) { try SpaceMAC.verify(mac: mac, expected: wrong) }
        }
        let cid = bytes("017112206428f02304b8db8cb107c89336481f0fead728bf374ca80168d2c71938cefae7")
        let uri = "at://did:example:alice/space/app.bsky.group/test/app.bsky.feed.post/1"
        #expect(try SpaceMAC.record(sharedSecret: secret, uri: uri, cid: cid) == bytes("b1000cbab95db1e15987c90d63eb3bdc76dbd64b921ca0ef5af842ad588da4c9"))
        #expect(throws: SpaceMAC.Failure.invalidKey) { try SpaceMAC.commit(sharedSecret: Data(), space: space, repo: repo, rev: rev, data: digest) }
    }
}
