import Foundation
import Petrel
@testable import PetrelRepo
import XCTest

final class RepositoryMSTVectorTests: XCTestCase {
    func testCanonicalEmptyNodeVector() throws {
        let node = RepositoryMSTNode(leftTreeCID: nil, entries: [])
        let bytes = try RepositoryMSTCodec.encode(node)

        XCTAssertEqual(bytes, PublicRepositoryGenesisCodec.canonicalEmptyMST)
        XCTAssertEqual(CID.fromDAGCBOR(bytes).string, PublicRepositoryGenesisCodec.canonicalEmptyMSTCID)
        XCTAssertEqual(try RepositoryMSTCodec.decode(bytes), node)
    }

    func testKeyDepthMatchesIndependentSHA256Vectors() {
        XCTAssertEqual(RepositoryMSTCodec.keyDepth(forASCIIKey: "app.bsky.feed.post/0"), 0)
        XCTAssertEqual(RepositoryMSTCodec.keyDepth(forASCIIKey: "app.bsky.feed.post/18"), 1)
        XCTAssertEqual(RepositoryMSTCodec.keyDepth(forASCIIKey: "app.bsky.feed.post/90"), 3)
    }

    func testDecodeRejectsCanonicalButInvalidPrefixCompression() throws {
        let recordCID = CID.fromDAGCBOR(Data([0xa0]))
        let bytes = try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
            (key: "l", value: NSNull()),
            (key: "e", value: [OrderedCBORMap(entries: [
                (key: "p", value: UInt64(1)),
                (key: "k", value: Data("x".utf8)),
                (key: "v", value: ATProtoLink(cid: recordCID)),
                (key: "t", value: NSNull()),
            ])] as [Any]),
        ]))
        XCTAssertThrowsError(try RepositoryMSTCodec.decode(bytes)) { error in
            XCTAssertEqual(error as? RepositoryMSTValidationError, .invalidPrefixCompression)
        }
    }

    func testEncodeRejectsNegativePrefixLengthWithoutTrapping() throws {
        let recordCID = CID.fromDAGCBOR(Data([0xa0]))
        let node = RepositoryMSTNode(leftTreeCID: nil, entries: [
            .init(prefixLength: -1, keySuffix: Data("x".utf8), valueCID: recordCID, rightTreeCID: nil),
        ])
        XCTAssertThrowsError(try RepositoryMSTCodec.encode(node)) { error in
            XCTAssertEqual(error as? RepositoryMSTValidationError, .invalidPrefixCompression)
        }
    }
    func testEncodeRejectsNonZeroFirstPrefixCompression() throws {
        let recordCID = CID.fromDAGCBOR(Data([0xa0]))
        let node = RepositoryMSTNode(leftTreeCID: nil, entries: [
            .init(prefixLength: 1, keySuffix: Data("app.bsky.feed.post/0".utf8), valueCID: recordCID, rightTreeCID: nil),
        ])
        XCTAssertThrowsError(try RepositoryMSTCodec.encode(node)) { error in
            XCTAssertEqual(error as? RepositoryMSTValidationError, .invalidPrefixCompression)
        }
    }

    func testEncodeRejectsNonMinimalPrefixCompression() throws {
        let recordCID = CID.fromDAGCBOR(Data([0xa0]))
        let node = RepositoryMSTNode(leftTreeCID: nil, entries: [
            .init(prefixLength: 0, keySuffix: Data("app.bsky.feed.post/a".utf8), valueCID: recordCID, rightTreeCID: nil),
            .init(prefixLength: 0, keySuffix: Data("app.bsky.feed.post/b".utf8), valueCID: recordCID, rightTreeCID: nil),
        ])
        XCTAssertThrowsError(try RepositoryMSTCodec.encode(node)) { error in
            XCTAssertEqual(error as? RepositoryMSTValidationError, .invalidPrefixCompression)
        }
    }

    func testEncodeRejectsKeysNotStrictlyIncreasing() throws {
        let recordCID = CID.fromDAGCBOR(Data([0xa0]))
        let node = RepositoryMSTNode(leftTreeCID: nil, entries: [
            .init(prefixLength: 0, keySuffix: Data("app.bsky.feed.post/2".utf8), valueCID: recordCID, rightTreeCID: nil),
            .init(prefixLength: 19, keySuffix: Data("1".utf8), valueCID: recordCID, rightTreeCID: nil),
        ])
        XCTAssertThrowsError(try RepositoryMSTCodec.encode(node)) { error in
            XCTAssertEqual(error as? RepositoryMSTValidationError, .keysNotStrictlyIncreasing)
        }
    }
    func testEncodeRejectsInvalidPathSyntax() throws {
        let recordCID = CID.fromDAGCBOR(Data([0xa0]))
        let node = RepositoryMSTNode(leftTreeCID: nil, entries: [
            .init(prefixLength: 0, keySuffix: Data("invalid-collection-no-slash".utf8), valueCID: recordCID, rightTreeCID: nil),
        ])
        XCTAssertThrowsError(try RepositoryMSTCodec.encode(node)) { error in
            XCTAssertEqual(error as? RepositoryMSTValidationError, .invalidPath)
        }
    }


    func testCanonicalPrefixCompressedNodeVector() throws {
        let first = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "0")
        let second = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "2")
        XCTAssertEqual(RepositoryMSTCodec.keyDepth(for: first), 0)
        XCTAssertEqual(RepositoryMSTCodec.keyDepth(for: second), 0)

        let firstRecord = Data([0xa1, 0x61, 0x61, 0x01])
        let secondRecord = Data([0xa1, 0x61, 0x62, 0x02])
        let node = try RepositoryMSTCodec.node(
            leaves: [
                .init(path: first, recordCID: CID.fromDAGCBOR(firstRecord), rightTreeCID: nil),
                .init(path: second, recordCID: CID.fromDAGCBOR(secondRecord), rightTreeCID: nil),
            ],
            leftTreeCID: nil
        )
        let encoded = try RepositoryMSTCodec.encode(node)
        let decoded = try RepositoryMSTCodec.decode(encoded)

        XCTAssertEqual(decoded.entries[0].prefixLength, 0)
        XCTAssertEqual(String(decoding: decoded.entries[0].keySuffix, as: UTF8.self), first.mstKey)
        XCTAssertEqual(decoded.entries[1].prefixLength, first.mstKey.utf8.count - 1)
        XCTAssertEqual(decoded.entries[1].keySuffix, Data("2".utf8))
        XCTAssertEqual(try RepositoryMSTCodec.reconstructedLeaves(from: decoded).map(\.path), [first, second])
        XCTAssertEqual(try RepositoryMSTCodec.encode(decoded), encoded)
    }

    func testPinnedTypeScriptSingleAndPrefixVectors() throws {
        try assertPinnedNode(
            cid: "bafyreigxprauwk4ns6l7xzjndh3llovaf2c6qvyf6ihybtqjbau4tp5bqm",
            hex: "a2616581a4616b546170702e62736b792e666565642e706f73742f306170006174f66176d82a582500017112209d156bc3f3a520066252c708a9361fd3d089223842500e3713d404fdccb33cef616cf6"
        )
        let prefixBytes = try assertPinnedNode(
            cid: "bafyreibypxbhnu73zvqc6pa64oxmzfkf62mjwx6ga332d4au4sx2cvhuye",
            hex: "a2616582a4616b546170702e62736b792e666565642e706f73742f306170006174f66176d82a582500017112209d156bc3f3a520066252c708a9361fd3d089223842500e3713d404fdccb33cefa4616b41326170136174f66176d82a582500017112209d156bc3f3a520066252c708a9361fd3d089223842500e3713d404fdccb33cef616cf6"
        )
        let decoded = try RepositoryMSTCodec.decode(prefixBytes)
        XCTAssertEqual(decoded.entries[1].prefixLength, 19)
        XCTAssertEqual(decoded.entries[1].keySuffix, Data("2".utf8))
    }

    func testPinnedTypeScriptDepthGapVector() throws {
        let blocks = [
            (
                "bafyreigahoij4l65qusqdw73mvk7yrwyty3h7cuo7w2twzke7n56sfpq4u",
                "a2616581a4616b556170702e62736b792e666565642e706f73742f39306170006174f66176d82a582500017112209d156bc3f3a520066252c708a9361fd3d089223842500e3713d404fdccb33cef616cd82a58250001711220d7e7fe001000f8cdf11c6919c4c2898a43a8b9b3fd2e7a51ba39bb1e6f029902"
            ),
            (
                "bafyreigx477aaeaa7dg7chdjdhcmfcmkioultm75fz5fdorzxmpg6auzai",
                "a2616580616cd82a582500017112204ac5d53d7733c26d631020964e2241bb9c00fcd949f24f5430e7268031752f5c"
            ),
            (
                "bafyreickyxkt25ztyjwwgebaszhceqn3tqapzwkj6jhvimhhe2adc5jplq",
                "a2616581a4616b556170702e62736b792e666565642e706f73742f31386170006174f66176d82a582500017112209d156bc3f3a520066252c708a9361fd3d089223842500e3713d404fdccb33cef616cd82a58250001711220d77c414b2b8d9797fbe52d19f6b5baa02e85e85705f20f80ce090829c9bfa183"
            ),
            (
                "bafyreigxprauwk4ns6l7xzjndh3llovaf2c6qvyf6ihybtqjbau4tp5bqm",
                "a2616581a4616b546170702e62736b792e666565642e706f73742f306170006174f66176d82a582500017112209d156bc3f3a520066252c708a9361fd3d089223842500e3713d404fdccb33cef616cf6"
            ),
        ]
        for block in blocks {
            _ = try assertPinnedNode(cid: block.0, hex: block.1)
        }
        XCTAssertEqual(
            try CID.parse(blocks[0].0).string,
            "bafyreigahoij4l65qusqdw73mvk7yrwyty3h7cuo7w2twzke7n56sfpq4u"
        )
    }

    func testPinnedTypeScriptMixedDepthVector() throws {
        let blocks = [
            (
                "bafyreicqdt3lg5ol2owxxcxwvr56ahiwueuljvztpzqdqivyvv4s7b4md4",
                "a2616581a4616b556170702e62736b792e666565642e706f73742f39306170006174f66176d82a582500017112209d156bc3f3a520066252c708a9361fd3d089223842500e3713d404fdccb33cef616cd82a58250001711220ba445bc0281a13d33b7c00ef6035a21038725ac83f36f3b01702eb5a67aa6b34"
            ),
            (
                "bafyreidhxu53ofn7w4x3v4d25ky46ocehacdiycciv5dxcxpehrojlglre",
                "a2616581a4616b556170702e62736b792e666565642e706f73742f31386170006174d82a58250001711220b80d788a48eacea06fcffd24f1acf674c3940263945674ebec2af10324b701a56176d82a582500017112209d156bc3f3a520066252c708a9361fd3d089223842500e3713d404fdccb33cef616cd82a58250001711220d77c414b2b8d9797fbe52d19f6b5baa02e85e85705f20f80ce090829c9bfa183"
            ),
            (
                "bafyreif2irn4aka2cpjtw7aa55qdliqqhbzfvsb7g3z3afyc5nngpktlgq",
                "a2616581a4616b556170702e62736b792e666565642e706f73742f35346170006174f66176d82a582500017112209d156bc3f3a520066252c708a9361fd3d089223842500e3713d404fdccb33cef616cd82a5825000171122067bd3bb715bfb72fbaf07aeab1cf38443804346042457a3b8aef21e2e4accb89"
            ),
            (
                "bafyreifybv4iushkz2qg7t75ety2z5tuyokaey4ukz2ox3bk6ebsjnybuu",
                "a2616581a4616b546170702e62736b792e666565642e706f73742f326170006174f66176d82a582500017112209d156bc3f3a520066252c708a9361fd3d089223842500e3713d404fdccb33cef616cf6"
            ),
            (
                "bafyreigxprauwk4ns6l7xzjndh3llovaf2c6qvyf6ihybtqjbau4tp5bqm",
                "a2616581a4616b546170702e62736b792e666565642e706f73742f306170006174f66176d82a582500017112209d156bc3f3a520066252c708a9361fd3d089223842500e3713d404fdccb33cef616cf6"
            ),
        ]
        for block in blocks {
            _ = try assertPinnedNode(cid: block.0, hex: block.1)
        }
        XCTAssertEqual(try RepositoryMSTCodec.decode(Data(hex: blocks[0].1)).entries.count, 1)
    }

    @discardableResult
    private func assertPinnedNode(cid: String, hex: String) throws -> Data {
        let bytes = Data(hex: hex)
        XCTAssertEqual(CID.fromDAGCBOR(bytes).string, cid)
        XCTAssertEqual(try RepositoryMSTCodec.encode(RepositoryMSTCodec.decode(bytes)), bytes)
        return bytes
    }
}

private extension Data {
    init(hex: String) {
        precondition(hex.count.isMultiple(of: 2))
        var bytes: [UInt8] = []
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let end = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index ..< end], radix: 16) else {
                preconditionFailure("invalid checked-in hex vector")
            }
            bytes.append(byte)
            index = end
        }
        self.init(bytes)
    }
}
