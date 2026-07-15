import Foundation
@testable import Petrel
import Testing

@Suite("ATProtoLink CID Validation")
struct ATProtoLinkCIDValidationTests {
    @Test("raw and DAG-CBOR SHA-256 CIDs are accepted")
    func acceptsBlessedCIDs() throws {
        let cids = [
            CID.fromBlob(Data("raw-link".utf8)),
            CID.fromDAGCBOR(Data("dag-cbor-link".utf8)),
        ]

        for cid in cids {
            #expect(try ATProtoLink(cidString: cid.string).cid == cid)
            #expect(try JSONDecoder().decode(ATProtoLink.self, from: jsonData(for: cid)).cid == cid)
            #expect(throws: Never.self) {
                _ = try JSONEncoder().encode(ATProtoLink(cid: cid))
            }
            #expect(throws: Never.self) {
                _ = try ATProtoLink(cid: cid).toCBORValue()
            }
        }
    }

    @Test("non-ATProto codecs remain valid general CIDs but links reject them")
    func rejectsUnsupportedLinkCodecsWithoutNarrowingCIDParsing() throws {
        for codec in [CIDCodec.dagPB, .gitRaw, .identity] {
            let cid = makeCID(codec: codec, algorithm: Multihash.sha256Code, length: 32, digestCount: 32)

            #expect(try CID.parse(cid.string) == cid)
            expectStringAndDecoderRejection(of: cid)
            expectEncoderAndCBORRejection(of: cid)
        }
    }

    @Test("SHA-1 CIDs are rejected at every throwing boundary")
    func rejectsSHA1() {
        let cid = makeCID(
            codec: .raw,
            algorithm: Multihash.sha1Code,
            length: Multihash.sha1Length,
            digestCount: Int(Multihash.sha1Length)
        )

        expectStringAndDecoderRejection(of: cid)
        expectEncoderAndCBORRejection(of: cid)
    }

    @Test("SHA-256 CIDs with a non-32 declared length are rejected")
    func rejectsMalformedSHA256DeclaredLength() {
        let cid = makeCID(codec: .raw, algorithm: Multihash.sha256Code, length: 31, digestCount: 31)

        expectStringAndDecoderRejection(of: cid)
        expectEncoderAndCBORRejection(of: cid)
    }

    @Test("SHA-256 CIDs with a non-32 digest are rejected when encoded")
    func rejectsMalformedSHA256DigestCount() {
        let cid = makeCID(codec: .dagCBOR, algorithm: Multihash.sha256Code, length: 32, digestCount: 31)

        expectEncoderAndCBORRejection(of: cid)
    }

    private func expectStringAndDecoderRejection(of cid: CID) {
        #expect(throws: (any Error).self) {
            _ = try ATProtoLink(cidString: cid.string)
        }
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(ATProtoLink.self, from: jsonData(for: cid))
        }
    }

    private func expectEncoderAndCBORRejection(of cid: CID) {
        let link = ATProtoLink(cid: cid)

        #expect(throws: (any Error).self) {
            _ = try JSONEncoder().encode(link)
        }
        #expect(throws: (any Error).self) {
            _ = try link.toCBORValue()
        }
    }

    private func makeCID(
        codec: CIDCodec,
        algorithm: UInt8,
        length: UInt8,
        digestCount: Int
    ) -> CID {
        CID(
            codec: codec,
            multihash: Multihash(
                algorithm: algorithm,
                length: length,
                digest: Data(repeating: 0xA5, count: digestCount)
            )
        )
    }

    private func jsonData(for cid: CID) -> Data {
        Data(#"{"$link":"\#(cid.string)"}"#.utf8)
    }
}
