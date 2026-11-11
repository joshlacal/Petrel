import Foundation
import PetrelCore
import Testing

/// The blessed-CID rule and the canonical string form, which every
/// repository, CAR, MST and commit check in Petrel is derived from.
@Suite("CID: canonical string form and blessed formats")
struct CIDBlessedFormatTests {
    private let dagCBOR = CID.fromDAGCBOR(Data("record".utf8))
    private let raw = CID.fromBlob(Data("blob".utf8))

    @Test("the canonical string round-trips, and only the canonical string parses")
    func canonicalStringOnly() throws {
        for cid in [dagCBOR, raw] {
            let string = cid.string
            #expect(string.count == 59)
            #expect(string.hasPrefix("baf"))
            #expect(try CID.parse(string) == cid)

            // Mixed or upper case: multibase `b` is lower-case base32.
            #expect(throws: CID.CIDParseError.self) { try CID.parse("b" + string.dropFirst().uppercased()) }
            var mixed = Array(string)
            mixed[10] = Character(String(mixed[10]).uppercased())
            if String(mixed) != string {
                #expect(throws: CID.CIDParseError.self) { try CID.parse(String(mixed)) }
            }
            // One surplus character whose bits the decoder would drop.
            for extra in ["a", "q", "7"] {
                #expect(throws: CID.CIDParseError.self) { try CID.parse(string + extra) }
            }
            // Other multibase prefixes and padding are not this encoding.
            #expect(throws: CID.CIDParseError.self) { try CID.parse("B" + string.dropFirst().uppercased()) }
            #expect(throws: CID.CIDParseError.self) { try CID.parse(string + "=") }
            #expect(throws: CID.CIDParseError.self) { try CID.parse(String(string.dropLast())) }
            #expect(throws: CID.CIDParseError.self) { try CID.parse("") }
        }
    }

    @Test("non-zero padding bits in the last character are refused")
    func nonZeroPaddingBits() throws {
        // 36 bytes are 288 bits: 57 full base32 characters and one more that
        // carries 3 data bits and 2 padding bits. Any last character that
        // differs only in those 2 bits decodes to the same bytes.
        let string = dagCBOR.string
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz234567")
        let last = try #require(string.last)
        let index = try #require(alphabet.firstIndex(of: last))
        #expect(index % 4 == 0, "the canonical last character has zero padding bits")
        for padding in 1 ... 3 {
            let alias = String(string.dropLast()) + String(alphabet[index + padding])
            #expect(throws: CID.CIDParseError.self, "\(alias)") { try CID.parse(alias) }
        }
    }

    @Test("blessedKind classifies CIDs; parseBlessed accepts exactly the blessed ones")
    func blessedFormats() throws {
        #expect(dagCBOR.blessedKind == .dagCBOR)
        #expect(raw.blessedKind == .raw)
        #expect(dagCBOR.isBlessed && raw.isBlessed)
        #expect(try CID.parseBlessed(dagCBOR.string) == dagCBOR)
        #expect(try CID.parseBlessed(dagCBOR.string, kind: .dagCBOR) == dagCBOR)
        #expect(try CID.parseBlessed(raw.string, kind: .raw) == raw)
        #expect(throws: CID.CIDParseError.self) { try CID.parseBlessed(raw.string, kind: .dagCBOR) }
        #expect(throws: CID.CIDParseError.self) { try CID.parseBlessed(dagCBOR.string, kind: .raw) }

        let digest32 = Data(repeating: 1, count: 32)
        let notBlessed = [
            // Another codec.
            CID(codec: .dagPB, multihash: Multihash(algorithm: Multihash.sha256Code, length: 32, digest: digest32)),
            // Another hash function.
            CID(codec: .dagCBOR, multihash: Multihash(
                algorithm: Multihash.sha512Code, length: 64, digest: Data(repeating: 1, count: 64)
            )),
            // SHA-256 truncated to 16 bytes.
            CID(codec: .dagCBOR, multihash: Multihash(
                algorithm: Multihash.sha256Code, length: 16, digest: Data(repeating: 1, count: 16)
            )),
        ]
        for cid in notBlessed {
            #expect(cid.blessedKind == nil)
            #expect(!cid.isBlessed)
            // It is a well-formed CID and parses as one...
            #expect(try CID.parse(cid.string) == cid)
            #expect(try CID(bytes: cid.bytes) == cid)
            // ...but is not accepted where a blessed CID is required,
            #expect(throws: CID.CIDParseError.self) { try CID.parseBlessed(cid.string) }
            // cannot be content-checked,
            #expect(!cid.matchesContent(Data()))
            // and cannot be written as a `cid-link`.
            #expect(throws: DAGCBORError.self) { try DAGCBOR.encodeValue(ATProtoLink(cid: cid)) }
        }
    }

    @Test("matchesContent hashes the bytes")
    func matchesContent() {
        #expect(dagCBOR.matchesContent(Data("record".utf8)))
        #expect(!dagCBOR.matchesContent(Data("recorD".utf8)))
        #expect(raw.matchesContent(Data("blob".utf8)))
        #expect(!raw.matchesContent(Data()))
    }

    @Test("repositoryBlock decode limits admit a large legal block that the standard limits refuse")
    func repositoryBlockLimits() throws {
        // An array of 20,000 small integers inside a map: about 20 KB,
        // far below any record size limit, but more than 10,000 values.
        var bytes: [UInt8] = [0xa1, 0x61, 0x61, 0x99, 0x4e, 0x20]
        bytes += [UInt8](repeating: 0x01, count: 20_000)
        let data = Data(bytes)
        #expect(throws: DAGCBORError.self) { try DAGCBOR.decodeCBORPreflight(data) }
        try DAGCBOR.decodeCBORPreflight(data, limits: .repositoryBlock)
    }
}
