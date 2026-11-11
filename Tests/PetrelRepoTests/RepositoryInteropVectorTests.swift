import Foundation
import Petrel
import PetrelRepo
import Testing

/// Official `mst/` vectors from bluesky-social/atproto-interop-tests, read
/// from disk and run in full.
@Suite("MST interop vectors")
struct RepositoryInteropVectorTests {
    private struct KeyHeight: Decodable {
        let key: String
        let height: Int
    }

    private struct CommonPrefix: Decodable {
        let left: String
        let right: String
        let len: Int
    }

    @Test("key_heights.json: every key has the listed depth")
    func keyHeights() throws {
        let vectors = try Vectors.decode([KeyHeight].self, "mst/key_heights.json")
        #expect(vectors.count == 9)
        for vector in vectors {
            #expect(
                RepositoryMSTCodec.keyDepth(forASCIIKey: vector.key) == vector.height,
                "key \(vector.key)"
            )
        }
    }

    @Test("common_prefix.json: every pair has the listed shared prefix length")
    func commonPrefix() throws {
        let vectors = try Vectors.decode([CommonPrefix].self, "mst/common_prefix.json")
        #expect(!vectors.isEmpty)
        for vector in vectors {
            // The file counts bytes of the UTF-8 encoding, which is how keys
            // are compared and compressed in a node.
            #expect(
                RepositoryMSTCodec.commonPrefixLength(
                    Data(vector.left.utf8), Data(vector.right.utf8)
                ) == vector.len,
                "\(vector.left) / \(vector.right)"
            )
        }
    }

    @Test("example_keys.txt: the digit after the letter is the key's depth")
    func exampleKeys() throws {
        let text = String(decoding: try Vectors.data("mst/example_keys.txt"), as: UTF8.self)
        let keys = text.split(separator: "\n").map(String.init)
        #expect(keys.count == 156)
        for key in keys {
            // Keys look like `C2/014073`: letter, intended depth, `/`, digits.
            let expected = try #require(Int(String(key[key.index(after: key.startIndex)])))
            #expect(RepositoryMSTCodec.keyDepth(forASCIIKey: key) == expected, "key \(key)")
            // They are valid tree keys but not repository paths.
            let path = try PublicRepositoryPath(mstKey: key, syntax: .mstKey)
            #expect(path.keyDepth == expected)
            #expect(throws: PublicRepositoryDomainError.self) {
                try PublicRepositoryPath(mstKey: key, syntax: .repositoryPath)
            }
        }
    }

    @Test("the repository specification's worked key-depth examples")
    func specificationExamples() {
        #expect(RepositoryMSTCodec.keyDepth(forASCIIKey: "2653ae71") == 0)
        #expect(RepositoryMSTCodec.keyDepth(forASCIIKey: "blue") == 1)
        #expect(RepositoryMSTCodec.keyDepth(forASCIIKey: "app.bsky.feed.post/454397e440ec") == 4)
        #expect(RepositoryMSTCodec.keyDepth(forASCIIKey: "app.bsky.feed.post/9adeb165882c") == 8)
    }

    @Test("tree-level key syntax follows the reference implementation's rule")
    func mstKeySyntax() throws {
        for valid in ["a/b", "A0/374913", "coll/key_~.:-", "app.bsky.feed.post/3lon5dzeaihj2"] {
            #expect(try PublicRepositoryPath(mstKey: valid, syntax: .mstKey).mstKey == valid)
        }
        for invalid in ["", "nokey", "/key", "coll/", "a/b/c", "coll/k ey", "coll/k#y", "coll/é"] {
            #expect(throws: PublicRepositoryDomainError.self, "\(invalid)") {
                try PublicRepositoryPath(mstKey: invalid, syntax: .mstKey)
            }
        }
        let long = "c/" + String(repeating: "k", count: 1_023)
        #expect(throws: PublicRepositoryDomainError.pathTooLong) {
            try PublicRepositoryPath(mstKey: long, syntax: .mstKey)
        }
    }
}
