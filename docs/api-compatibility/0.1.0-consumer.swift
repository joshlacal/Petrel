// Source-compatibility probe compiled against the real warmed Petrel modules.
// This file deliberately imports Petrel, not PetrelCore or @testable Petrel.
// Its function bodies are compiled to a Mach-O object; they are not executed.
import Foundation
import Petrel

struct ConsumerValue: Petrel.ATProtocolCodable, Petrel.DAGCBORCodable {
    let text: String

    func toCBORValue() throws -> Any { ["text": text] }
}

func protocolSurface<T: Petrel.DAGCBORCodable>(_ value: T, data: Data) throws {
    let encodable: any Petrel.DAGCBOREncodable = value
    let decodable: any Petrel.DAGCBORDecodable.Type = T.self
    _ = try encodable.toCBORValue()
    _ = try encodable.encodedDAGCBOR()
    _ = try decodable.decodedFromDAGCBOR(data)
    _ = try Petrel.DAGCBOR.encode(value)
    let _: T = try Petrel.DAGCBOR.decode(data)
    _ = try Petrel.DAGCBOR.encodeValue(["text": "consumer"])
    _ = try ConsumerValue.decodedFromDAGCBOR(data)
    _ = try [ConsumerValue(text: "consumer")].toCBORValue()
    _ = try [ConsumerValue(text: "consumer")].encodedDAGCBOR()
    let _: [Petrel.DAGCBORError] = [
        .encodingFailed("consumer"), .decodingFailed("consumer"),
        .unsupportedType("consumer"), .invalidCIDEncoding("consumer"),
        .invalidMapKey, .floatingPointNotAllowed,
    ]
}

func migratedCoreNames(data: Data, encoder: any Encoder, decoder: any Decoder) throws {
    let codec: Petrel.CIDCodec = .dagCBOR
    let codecs: [CIDCodec] = [.raw, .dagPB, .dagCBOR, .gitRaw, .identity]
    let rawValue: Petrel.CIDCodec.RawValue = codec.rawValue
    _ = Petrel.CIDCodec(rawValue: rawValue)
    _ = try codec.toCBORValue()
    _ = codecs

    let algorithms: [UInt8] = [
        Petrel.Multihash.sha1Code, Multihash.sha1Length,
        Multihash.sha256Code, Multihash.sha256Length,
        Multihash.sha512Code, Multihash.sha512Length,
        Multihash.blake2b256Code, Multihash.blake2b256Length,
    ]
    let multihash: Petrel.Multihash = Multihash(
        algorithm: Multihash.sha256Code,
        length: Multihash.sha256Length,
        digest: Data(repeating: 0, count: 32)
    )
    _ = algorithms
    _ = multihash.algorithmName
    _ = multihash.algorithm
    _ = multihash.length
    _ = multihash.digest
    _ = multihash.bytes
    _ = multihash.hashValue
    _ = try multihash.toCBORValue()
    _ = Petrel.Multihash.sha256(data)
    try multihash.encode(to: encoder)
    _ = try Petrel.Multihash(from: decoder)
    var hasher = Hasher()
    multihash.hash(into: &hasher)

    let cid: Petrel.CID = CID(codec: codec, multihash: multihash)
    _ = cid.codec
    _ = cid.multihash
    _ = cid.bytes
    _ = cid.string
    _ = cid.description
    _ = cid.hashValue
    _ = Petrel.CID.fromDAGCBOR(data)
    _ = Petrel.CID.fromBlob(data)
    _ = try Petrel.CID.parse(cid.string)
    _ = try Petrel.CID(bytes: cid.bytes)
    _ = try Petrel.CID(from: decoder)
    try cid.encode(to: encoder)
    _ = try cid.toCBORValue()
    cid.hash(into: &hasher)
    let _: [Petrel.CID.CIDParseError] = [
        .invalidPrefix("consumer"), .invalidBase32Encoding, .insufficientLength,
        .invalidVersion(0), .unsupportedCodec(0), .invalidHashAlgorithm(0, 0),
    ]

    let link: Petrel.ATProtoLink = ATProtoLink(cid: cid)
    _ = link.cid
    _ = link.hashValue
    _ = try Petrel.ATProtoLink(cidString: cid.string)
    _ = try Petrel.ATProtoLink(from: decoder)
    try link.encode(to: encoder)
    link.hash(into: &hasher)
    _ = try link.toCBORValue()
    let codable: any Petrel.ATProtocolCodable = link
    let value: any Petrel.ATProtocolValue = link
    _ = link.isEqual(to: codable)
    _ = link.isEqual(to: value)
    let oldEquality: (any Petrel.ATProtocolCodable) -> Bool = link.isEqual(to:)
    _ = oldEquality(codable)

    let qualifiedEncoding = Petrel.base32Encode(data)
    _ = Petrel.base32Decode(qualifiedEncoding)
    _ = base32Decode(base32Encode(data))
    _ = data.hexDump()

    var map: Petrel.OrderedCBORMap = OrderedCBORMap()
    map = OrderedCBORMap(entries: [(key: "link", value: link)])
    map = map.adding(key: "cid", value: cid)
    _ = map.entries
    _ = map.description
    _ = try map.toCBORValue()
    _ = try DAGCBOR.encode(map)
    _ = try DAGCBOR.encodeValue(map)
}

func migratedCARNames(data: Data, fileURL: URL, cid: Petrel.CID) throws {
    let reader: Petrel.CARReader = try CARReader(data: data)
    _ = try Petrel.CARReader(fileURL: fileURL)
    let locations: [String: Petrel.CARReader.BlockLocation] = reader.blockIndex
    _ = locations.values.map { ($0.dataOffset, $0.dataLength) }
    let _: [Petrel.CID] = reader.roots
    _ = try reader.readVarint()
    _ = try reader.decodeBlock(for: cid.bytes)
    _ = try reader.decodeBlock(for: cid)
    _ = try reader.decodeBlock(for: cid.string)
    _ = try reader.rawBlockData(for: cid.bytes)
    _ = try reader.rawBlockData(for: cid)
    _ = try reader.rawBlockData(for: cid.string)
    let errors: [Petrel.CARReaderError] = [
        .invalidHeader("consumer"), .invalidVarint, .unexpectedEOF,
        .invalidCID("consumer"), .blockNotFound("consumer"), .decodingFailed("consumer"),
    ]
    _ = errors.map(\.errorDescription)
}

func oldConstructorCalls(
    url: URL, authProvider: (any Petrel.AuthenticationProvider)?,
    cid: Petrel.CID, profile: Petrel.AppBskyActorDefs.ProfileViewBasic,
    record: Petrel.ATProtocolValueContainer, did: Petrel.DID,
    uri: Petrel.URI, timestamp: Petrel.ATProtocolDate,
    revision: Petrel.TID, bytes: Petrel.Bytes
) {
    _ = Petrel.OAuthState(
        stateToken: "compile-only", codeVerifier: "compile-only", createdAt: Date(),
        initialIdentifier: nil, targetPDSURL: nil, ephemeralDPoPKey: nil,
        parResponseNonce: nil, bskyAppViewDID: nil, bskyChatDID: nil
    )
    _ = Petrel.NetworkService(baseURL: url, authService: authProvider)
    _ = Petrel.AppBskyFeedDefs.ViewerState(
        repost: nil, like: nil, bookmarked: nil, threadMuted: nil,
        replyDisabled: nil, embeddingDisabled: nil, pinned: nil
    )
    _ = Petrel.AppBskyFeedDefs.ViewerState()

    _ = Petrel.AppBskyActorDefs.StatusView(
        uri: nil, cid: cid, status: "consumer", record: record,
        embed: nil, labels: nil, expiresAt: nil, isActive: nil, isDisabled: nil
    )
    _ = Petrel.AppBskyFeedDefs.ReasonRepost(by: profile, uri: nil, cid: cid, indexedAt: timestamp)
    _ = Petrel.AppBskyFeedDefs.ThreadgateView(uri: nil, cid: cid, record: nil, lists: nil)
    _ = Petrel.ComAtprotoLabelDefs.Label(
        ver: nil, src: did, uri: uri, cid: cid, val: "consumer", neg: nil,
        cts: timestamp, exp: nil, sig: nil
    )
    let op = Petrel.ComAtprotoSyncSubscribeRepos.RepoOp(
        action: "create", path: "app.bsky.feed.post/consumer", cid: cid, prev: cid
    )
    _ = Petrel.ComAtprotoSyncSubscribeRepos.Commit(
        seq: 0, rebase: false, tooBig: false, repo: did, commit: cid,
        rev: revision, since: nil, blocks: bytes, ops: [op], blobs: [cid],
        prevData: cid, time: timestamp
    )
    // The constructor accepts a nonoptional CID through optional promotion.
    // Reading it as nonoptional is a separate negative-control fixture.
    let _: Petrel.CID? = op.cid
}
