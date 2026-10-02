import Foundation
#if canImport(Darwin)
import Darwin
#endif
import Petrel
import PetrelCore
import PetrelRepo
import CBenchMetrics

// DAG-CBOR / CAR lane. Modes (no latency timing anywhere in this file):
//   dagcbor-generate  build Fixtures/DAGCBOR/{repo-mix.car,manifest.json,edges.json} from the JSON corpus
//   dagcbor           differential dump of every production CBOR decode path (compare across binaries)
//   dagcbor-profile   loop one path for --seconds (for /usr/bin/sample attribution)
//   dagcbor-counts    deterministic malloc / retired-instruction counts per path

// MARK: - Fixture files

struct DAGCBORRecordEntry: Codable, Sendable {
    let path: String
    let cid: String
    let source: String
}

struct DAGCBOREdgeBlock: Codable, Sendable {
    let name: String
    let hex: String
    let note: String
}

struct DAGCBORManifest: Codable, Sendable {
    let car: String
    let carBytes: Int
    let carFingerprint: String
    let commitCID: String
    let mstRootCID: String
    let mstNodeBlocks: Int
    let recordBlocks: Int
    let records: [DAGCBORRecordEntry]
    let sourceCounts: [String: Int]
    let collectionCounts: [String: Int]
    let note: String
}

struct DAGCBORCorpus: Sendable {
    let manifest: DAGCBORManifest
    let carURL: URL
    let carData: Data
    /// Record blocks in MST path order (one entry per path; duplicates by CID are kept).
    let blocks: [(entry: DAGCBORRecordEntry, data: Data)]
    let edges: [(name: String, data: Data)]
}

func dagcborFingerprint(_ data: Data) -> String {
    CID.fromDAGCBOR(data).string
}

func hexString(_ data: Data) -> String {
    let digits = Array("0123456789abcdef".utf8)
    var out = [UInt8]()
    out.reserveCapacity(data.count * 2)
    for byte in data {
        out.append(digits[Int(byte >> 4)])
        out.append(digits[Int(byte & 0x0F)])
    }
    return String(decoding: out, as: UTF8.self)
}

func dataFromHex(_ hex: String) -> Data {
    var out = Data(capacity: hex.utf8.count / 2)
    var hi: UInt8?
    for c in hex.utf8 {
        let v: UInt8
        switch c {
        case 48 ... 57: v = c - 48
        case 97 ... 102: v = c - 87
        case 65 ... 70: v = c - 55
        default: continue
        }
        if let h = hi { out.append(h << 4 | v); hi = nil } else { hi = v }
    }
    return out
}

func loadDAGCBORCorpus(_ fixtureDir: String) throws -> DAGCBORCorpus {
    let dir = fixtureDir + "/DAGCBOR"
    let manifest = try JSONDecoder().decode(DAGCBORManifest.self, from: Data(contentsOf: URL(fileURLWithPath: dir + "/manifest.json")))
    let carURL = URL(fileURLWithPath: dir + "/" + manifest.car)
    let carData = try Data(contentsOf: carURL)
    guard dagcborFingerprint(carData) == manifest.carFingerprint else {
        throw BenchError.message("DAG-CBOR CAR fingerprint mismatch")
    }
    let reader = try CARReader(data: carData)
    var blocks: [(DAGCBORRecordEntry, Data)] = []
    blocks.reserveCapacity(manifest.records.count)
    for entry in manifest.records {
        blocks.append((entry, try reader.rawBlockData(for: try CID.parse(entry.cid))))
    }
    let edgeRows = try JSONDecoder().decode([DAGCBOREdgeBlock].self, from: Data(contentsOf: URL(fileURLWithPath: dir + "/edges.json")))
    var edges = edgeRows.map { ($0.name, dataFromHex($0.hex)) }
    // Large invalid inputs are synthesized deterministically instead of being checked in.
    edges.append(("garbage_reserved_64k", dagcborGarbage(65_536)))
    edges.append(("garbage_reserved_1m", dagcborGarbage(1_048_576)))
    edges.append(("truncated_bytestring_64k", dagcborTruncatedByteString(65_536)))
    return DAGCBORCorpus(manifest: manifest, carURL: carURL, carData: carData, blocks: blocks, edges: edges)
}

/// Starts with reserved additional-info byte 0x1c, so SwiftCBOR rejects it at byte 0 and the
/// failure message hex-dumps the whole input (the decodedFromDAGCBOR failure path).
func dagcborGarbage(_ count: Int) -> Data {
    var rng = RNG(state: UInt64(count))
    var bytes = [UInt8](repeating: 0, count: count)
    for i in bytes.indices { bytes[i] = UInt8(truncatingIfNeeded: rng.next() >> 33) }
    bytes[0] = 0x1c
    return Data(bytes)
}

/// A map whose byte-string value claims more bytes than remain (unfinishedSequence).
func dagcborTruncatedByteString(_ count: Int) -> Data {
    var bytes: [UInt8] = [0xa1, 0x61, 0x62, 0x5a, 0x7f, 0xff, 0xff, 0xff]
    var rng = RNG(state: 7)
    while bytes.count < count { bytes.append(UInt8(truncatingIfNeeded: rng.next() >> 29)) }
    return Data(bytes)
}

// MARK: - Fixture generation

enum DAGCBORGenError: Error { case unsupported(String) }

/// Wire-faithful raw container from JSONSerialization output (no $type resolution), so the
/// encoded blocks keep unknown fields exactly as a PDS would store them.
func rawContainer(fromJSON value: Any) throws -> ATProtocolValueContainer {
    switch value {
    case is NSNull:
        return .null
    case let s as String:
        return .string(s)
    case let n as NSNumber:
        #if canImport(Darwin)
        if CFGetTypeID(n as CFTypeRef) == CFBooleanGetTypeID() { return .bool(n.boolValue) }
        #endif
        let d = n.doubleValue
        guard d.rounded() == d, abs(d) < 9.0e15 else { throw DAGCBORGenError.unsupported("non-integral number \(n)") }
        return .number(n.intValue)
    case let array as [Any]:
        return .array(try array.map { try rawContainer(fromJSON: $0) })
    case let object as [String: Any]:
        if object.count == 1, let link = object["$link"] as? String {
            return .link(try ATProtoLink(cidString: link))
        }
        if object.count == 1, let b64 = object["$bytes"] as? String {
            guard let data = Data(base64Encoded: b64) else { throw DAGCBORGenError.unsupported("bad base64") }
            return .bytes(Bytes(data: data))
        }
        var dict: [String: ATProtocolValueContainer] = [:]
        for (k, v) in object { dict[k] = try rawContainer(fromJSON: v) }
        return .object(dict)
    default:
        throw DAGCBORGenError.unsupported("\(type(of: value))")
    }
}

func generateDAGCBORFixture(fixtureDir: String) async throws {
    struct Pending { let collection: String; let source: String; let bytes: Data }
    var pending: [Pending] = []
    var skipped: [String] = []

    func add(_ json: Any, source: String, collectionOverride: String? = nil) {
        do {
            let raw = try rawContainer(fromJSON: json)
            let bytes = try raw.encodedDAGCBOR()
            var collection = collectionOverride ?? "test.example.edge"
            if collectionOverride == nil, let obj = json as? [String: Any], let t = obj["$type"] as? String,
               !t.contains("#"), t.split(separator: ".").count >= 3
            {
                collection = t
            }
            pending.append(Pending(collection: collection, source: source, bytes: bytes))
        } catch {
            skipped.append("\(source): \(error)")
        }
    }

    func load(_ name: String) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: fixtureDir + "/" + name)))
    }

    // 1. Repository records embedded in the JSON timelines (PostView.record, ViewRecord.value).
    var authors: [String] = []
    var seenAuthors = Set<String>()
    var postSubjects: [(uri: String, cid: String, at: String)] = []
    var repostSubjects: [(uri: String, cid: String, at: String)] = []
    var blobRefs: [[String: Any]] = []
    func walk(_ value: Any, feed: String) {
        if let object = value as? [String: Any] {
            let looksLikeView = object["uri"] is String && object["cid"] is String && object["author"] is [String: Any]
            if looksLikeView {
                if let record = object["record"] as? [String: Any], record["$type"] is String {
                    add(record, source: "\(feed):record")
                }
                if let record = object["value"] as? [String: Any], record["$type"] is String {
                    add(record, source: "\(feed):value")
                }
                if let author = object["author"] as? [String: Any], let did = author["did"] as? String, seenAuthors.insert(did).inserted {
                    authors.append(did)
                }
                if object["$type"] as? String == "app.bsky.feed.defs#postView" || object["indexedAt"] is String,
                   let uri = object["uri"] as? String, let cid = object["cid"] as? String, uri.contains("/app.bsky.feed.post/")
                {
                    postSubjects.append((uri, cid, object["indexedAt"] as? String ?? "2026-01-01T00:00:00.000Z"))
                }
            }
            if object["$type"] as? String == "blob", blobRefs.count < 4 { blobRefs.append(object) }
            for key in object.keys.sorted() { walk(object[key]!, feed: feed) }
        } else if let array = value as? [Any] {
            for element in array { walk(element, feed: feed) }
        }
    }
    for feed in ["large-feed", "unicode-feed", "difficult-feed"] {
        let root = try load(feed + ".json")
        walk(root, feed: feed)
        if let items = (root as? [String: Any])?["feed"] as? [Any] {
            for case let item as [String: Any] in items {
                if let reason = item["reason"] as? [String: Any], reason["$type"] as? String == "app.bsky.feed.defs#reasonRepost",
                   let post = item["post"] as? [String: Any], let uri = post["uri"] as? String, let cid = post["cid"] as? String
                {
                    repostSubjects.append((uri, cid, reason["indexedAt"] as? String ?? "2026-01-01T00:00:00.000Z"))
                }
            }
        }
    }

    // 2. The small records that dominate real repositories (likes, reposts, follows, blocks, profile).
    for s in postSubjects {
        add(["$type": "app.bsky.feed.like", "subject": ["uri": s.uri, "cid": s.cid], "createdAt": s.at], source: "synth:like")
    }
    for s in repostSubjects {
        add(["$type": "app.bsky.feed.repost", "subject": ["uri": s.uri, "cid": s.cid], "createdAt": s.at], source: "synth:repost")
    }
    for did in authors {
        add(["$type": "app.bsky.graph.follow", "subject": did, "createdAt": "2026-01-01T00:00:00.000Z"], source: "synth:follow")
    }
    for did in authors.prefix(3) {
        add(["$type": "app.bsky.graph.block", "subject": did, "createdAt": "2026-01-02T00:00:00.000Z"], source: "synth:block")
    }
    if blobRefs.count >= 2 {
        add([
            "$type": "app.bsky.actor.profile", "displayName": "Bench Fixture 🦋", "description": "Synthetic DAG-CBOR profile record.",
            "avatar": blobRefs[0], "banner": blobRefs[1], "createdAt": "2026-01-01T00:00:00.000Z",
        ], source: "synth:profile")
    }

    // 3. Binary-heavy extension records (exact IPLD bytes) from the base64 corpus.
    if let records = (try load("base64-records.json") as? [String: Any])?["records"] as? [Any] {
        for case let record as [String: Any] in records.prefix(4) {
            if let value = record["value"] { add(value, source: "base64-records:value") }
        }
    }

    // 4. Known/unknown classification edge records (the DAG-CBOR-representable subset of the
    //    dynamic-container lane's edge list).
    let date = "2026-01-01T00:00:00.000Z"
    let cid = "bafkreifqkz7gikummmwlitlxwfqnverjhacyeu4i3dytnmhn5bmuowkzoy"
    let strongRefCID = "bafyreibe7vchdsgdlh7w3zjd5bhn566yranqwfojxbkck2yjcypzmcg7dq"
    let post = { (extra: String) in #"{"$type":"app.bsky.feed.post","text":"hello","createdAt":"\#(date)"\#(extra)}"# }
    let edgeJSON: [(String, String)] = [
        ("known_minimal", post("")),
        ("extra_field_bool", post(#","future":true"#)),
        ("extra_field_nested_known", post(#","future":{"$type":"app.bsky.richtext.facet#tag","tag":"x"}"#)),
        ("optional_degraded_rawok", post(#","langs":3"#)),
        ("lang_region", post(#","langs":["zh-Hans-CN","en-US"]"#)),
        ("long_fraction_date", #"{"$type":"app.bsky.feed.post","text":"t","createdAt":"2026-07-20T14:13:03.720942844Z"}"#),
        ("facet_link_trim", post(#","facets":[{"index":{"byteStart":0,"byteEnd":5},"features":[{"$type":"app.bsky.richtext.facet#link","uri":" https://example.com "}]}]"#)),
        ("facet_unknown_feature", post(#","facets":[{"index":{"byteStart":0,"byteEnd":5},"features":[{"$type":"example.future.facet","value":true}]}]"#)),
        ("facet_index_framed", post(#","facets":[{"index":{"$type":"app.bsky.richtext.facet#byteSlice","byteStart":0,"byteEnd":5},"features":[{"$type":"app.bsky.richtext.facet#tag","tag":"x"}]}]"#)),
        ("facet_index_wrong_type", post(#","facets":[{"index":{"$type":"app.bsky.richtext.facet#tag","tag":"x","byteStart":0,"byteEnd":5},"features":[{"$type":"app.bsky.richtext.facet#tag","tag":"x"}]}]"#)),
        ("strongref_with_foreign_type", post(#","reply":{"root":{"$type":"app.bsky.richtext.facet#tag","tag":"t","uri":"at://did:plc:abc/app.bsky.feed.post/1","cid":"\#(strongRefCID)"},"parent":{"uri":"at://did:plc:abc/app.bsky.feed.post/1","cid":"\#(strongRefCID)"}}"#)),
        ("strongref_with_own_type", post(#","reply":{"root":{"$type":"com.atproto.repo.strongRef","uri":"at://did:plc:abc/app.bsky.feed.post/1","cid":"\#(strongRefCID)"},"parent":{"uri":"at://did:plc:abc/app.bsky.feed.post/1","cid":"\#(strongRefCID)"}}"#)),
        ("embed_images_nested_unknown_blob_field", post(#","embed":{"$type":"app.bsky.embed.images","images":[{"alt":"a","image":{"$type":"blob","ref":{"$link":"\#(cid)"},"mimeType":"image/png","size":1,"future":"x"}}]}"#)),
        ("embed_union_unknown_member", post(#","embed":{"$type":"example.future.embed","payload":{"$type":"app.bsky.richtext.facet#tag","tag":"y"},"n":[1,2,3]}"#)),
        ("embed_union_known_but_invalid", post(#","embed":{"$type":"app.bsky.embed.external","external":{"uri":"https://a.example","title":5}}"#)),
        ("type_not_string", #"{"$type":5,"text":"x","createdAt":"\#(date)"}"#),
        ("type_null", #"{"$type":null,"text":"x","createdAt":"\#(date)"}"#),
        ("text_wrong_type", #"{"$type":"app.bsky.feed.post","text":42,"createdAt":"\#(date)"}"#),
        ("missing_required", #"{"$type":"app.bsky.feed.post","text":"x"}"#),
        ("unknown_wrapping_known", #"{"$type":"example.unknown","inner":\#(post("")),"list":[\#(post("")),null,1,"s"]}"#),
        ("explicit_nulls", post(#","embed":{"$type":"app.bsky.embed.images","captions":[],"external":null,"images":[{"alt":"a","aspectRatio":{"height":1,"width":2},"image":{"$type":"blob","ref":{"$link":"\#(cid)"},"mimeType":"image/jpeg","size":3}}],"record":null},"facets":[{"features":[{"$type":"app.bsky.richtext.facet#mention","did":"did:plc:mrvatd2g4xdzxlcdam3ljnxc","tag":null,"uri":null}],"index":{"byteEnd":4,"byteStart":0}}]"#)),
        ("special_lookalike_in_known", post(#","future":{"$link":"x","extra":1}"#)),
        ("bytes_in_unknown", #"{"$type":"example.unknown","b":{"$bytes":"AAH/"},"l":{"$link":"\#(cid)"}}"#),
        ("label_uri_trim", #"{"$type":"com.atproto.label.defs#label","src":"did:plc:example1234567890abcdef","uri":" https://example.com/item ","val":"test-label","cts":"\#(date)"}"#),
        ("strongref_root", #"{"$type":"com.atproto.repo.strongRef","uri":"at://did:plc:abc/app.bsky.feed.post/1","cid":"\#(strongRefCID)"}"#),
        ("preferences_array_type", #"{"$type":"app.bsky.actor.defs#preferences","items":[]}"#),
        ("empty_object", "{}"),
        ("like_with_extra", #"{"$type":"app.bsky.feed.like","subject":{"uri":"at://did:plc:abc/app.bsky.feed.post/1","cid":"\#(strongRefCID)","future":1},"createdAt":"\#(date)","via":{"uri":"at://did:plc:abc/app.bsky.feed.repost/1","cid":"\#(strongRefCID)"}}"#),
        ("follow_bad_did", #"{"$type":"app.bsky.graph.follow","subject":"not-a-did","createdAt":"\#(date)"}"#),
        ("profile_unknown_union", #"{"$type":"app.bsky.actor.profile","displayName":"x","labels":{"$type":"example.future.labels","values":[]},"pinnedPost":{"uri":"at://did:plc:abc/app.bsky.feed.post/1","cid":"\#(strongRefCID)"}}"#),
        ("deep_unknown_32", #"{"$type":"example.deep","v":"# + String(repeating: "[", count: 32) + "1" + String(repeating: "]", count: 32) + "}"),
    ]
    for (name, text) in edgeJSON {
        add(try JSONSerialization.jsonObject(with: Data(text.utf8)), source: "edge:\(name)")
    }

    // MST + commit + CAR (deterministic: paths are sequence-numbered, blocks sorted by CID).
    var mst = try RepositoryMST.empty()
    var entries: [DAGCBORRecordEntry] = []
    var recordBlocks: [CID: Data] = [:]
    for (index, item) in pending.enumerated() {
        let rkey = String(format: "r%06d", index)
        let path = try PublicRepositoryPath(collection: item.collection, recordKey: rkey)
        let recordCID = CID.fromDAGCBOR(item.bytes)
        mst = try await mst.adding(path: path, recordCID: recordCID)
        recordBlocks[recordCID] = item.bytes
        entries.append(DAGCBORRecordEntry(path: path.mstKey, cid: recordCID.string, source: item.source))
    }
    entries.sort { $0.path.utf8.lexicographicallyPrecedes($1.path.utf8) }
    let materialized = try await mst.materialized()
    let commit = try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
        (key: "did", value: "did:plc:dagcborbenchfixture000"),
        (key: "rev", value: "3lbenchfixture2"),
        (key: "sig", value: Data(repeating: 0, count: 64)),
        (key: "data", value: ATProtoLink(cid: materialized.rootCID)),
        (key: "prev", value: NSNull()),
        (key: "version", value: 3),
    ]))
    let commitCID = CID.fromDAGCBOR(commit)

    func varint(_ value: Int) -> Data {
        var v = UInt64(value); var out = Data()
        repeat { var b = UInt8(v & 0x7f); v >>= 7; if v != 0 { b |= 0x80 }; out.append(b) } while v != 0
        return out
    }
    var car = Data()
    let header = try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
        (key: "roots", value: [ATProtoLink(cid: commitCID)]),
        (key: "version", value: 1),
    ]))
    car.append(varint(header.count)); car.append(header)
    func appendBlock(_ cid: CID, _ bytes: Data) {
        car.append(varint(cid.bytes.count + bytes.count)); car.append(cid.bytes); car.append(bytes)
    }
    appendBlock(commitCID, commit)
    let mstCIDs = materialized.newBlocks.cids.sorted { $0.string < $1.string }
    for cid in mstCIDs {
        guard let bytes = try await materialized.newBlocks.block(for: cid) else { throw BenchError.message("missing MST block") }
        appendBlock(cid, bytes)
    }
    for cid in recordBlocks.keys.sorted(by: { $0.string < $1.string }) { appendBlock(cid, recordBlocks[cid]!) }

    var sourceCounts: [String: Int] = [:], collectionCounts: [String: Int] = [:]
    for item in pending {
        sourceCounts[item.source.hasPrefix("edge:") ? "edge" : item.source, default: 0] += 1
        collectionCounts[item.collection, default: 0] += 1
    }
    let dir = fixtureDir + "/DAGCBOR"
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    try car.write(to: URL(fileURLWithPath: dir + "/repo-mix.car"), options: .atomic)
    let manifest = DAGCBORManifest(
        car: "repo-mix.car", carBytes: car.count, carFingerprint: dagcborFingerprint(car),
        commitCID: commitCID.string, mstRootCID: materialized.rootCID.string,
        mstNodeBlocks: mstCIDs.count, recordBlocks: recordBlocks.count, records: entries,
        sourceCounts: sourceCounts, collectionCounts: collectionCounts,
        note: "Deterministic synthetic repository CAR. Records are wire-faithful DAG-CBOR encodings (Petrel encoder over raw, unresolved containers) of the repo records embedded in large-feed, unicode-feed and difficult-feed, plus synthesized likes/reposts/follows/blocks/profile, 4 base64-records binary records and classification edge records. Commit is unsigned (sig = 64 zero bytes); MST built with PetrelRepo.RepositoryMST. Skipped: \(skipped.count)."
    )
    try save(manifest, dir + "/manifest.json")
    try save(dagcborEdgeBlocks(), dir + "/edges.json")
    progress("DAGCBOR fixture: \(entries.count) record paths, \(recordBlocks.count) record blocks, \(mstCIDs.count) MST nodes, CAR \(car.count) bytes; skipped \(skipped.count)")
    for s in skipped { progress("  skipped \(s)") }
}

/// Hand-built malformed / quirk blocks (not valid repository records).
func dagcborEdgeBlocks() -> [DAGCBOREdgeBlock] {
    var rows: [DAGCBOREdgeBlock] = []
    func add(_ name: String, _ hex: String, _ note: String) { rows.append(.init(name: name, hex: hex, note: note)) }
    // Generated by Benchmarks/JSON/dagcbor_edges.py (byte-exact CBOR, documented per row).
    add("empty", "", "empty input")
    add("scalar_root_uint", "05", "root is a scalar")
    add("scalar_root_text", "6161", "root is a text string")
    add("root_array", "82a0a16161f5", "root array of maps")
    add("float64_value", "a16161fb3ff8000000000000", "float value")
    add("float16_value", "a16161f93c00", "half float value")
    add("uint_above_int_max", "a1616e1b8000000000000000", "2^63: throws in decodedFromDAGCBOR, stringified in CARRepository")
    add("uint_max", "a1616e1bffffffffffffffff", "2^64-1")
    add("negint_below_int64_min", "a1616e3bffffffffffffffff", "-2^64")
    add("negint_int64_min", "a1616e3b7fffffffffffffff", "-2^63")
    add("tag43", "a16178d82b4100", "unsupported tag")
    add("tag42_no_prefix", "a16178d82a582401711220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", "tag 42 payload without 0x00 prefix")
    add("tag42_bad_cid", "a16178d82a4400010203", "tag 42 with invalid CID bytes")
    add("tag42_text", "a16178d82a6161", "tag 42 wrapping text")
    add("tag42_valid", "a16178d82a58250001711220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", "valid tag 42 link")
    add("int_map_key", "a1016161", "integer map key")
    add("link_non_string", "a165246c696e6b05", "{$link: 5}")
    add("link_bad_cid_short", "a165246c696e6b676e6f7461636964", "{$link: notacid}")
    add("link_bad_cid_base32", "a165246c696e6b7562616679212121216e6f7462617365333221212121", "{$link: b... invalid base32}")
    add("link_with_typed_value", "a165246c696e6ba2637461676178652474797065781b6170702e62736b792e72696368746578742e666163657423746167", "{$link: {typed object}} (resolution must not change the string check)")
    add("bytes_bad_base64", "a16624627974657363212121", "{$bytes: !!!}")
    add("bytes_non_string", "a166246279746573f5", "{$bytes: true}")
    add("bytes_valid", "a166246279746573644141482f", "{$bytes: AAH/}")
    add("type_typed_value", "a2616101652474797065a2637461676178652474797065781b6170702e62736b792e72696368746578742e666163657423746167", "{$type: {typed object}, a: 1}")
    add("noncanonical_key_order", "a2616201616102", "{b:1,a:2} accepted by decodedFromDAGCBOR, rejected by preflight")
    add("duplicate_keys", "a2616101616102", "{a:1,a:2} last wins in SwiftCBOR")
    add("indefinite_map", "bf616101ff", "indefinite-length map")
    add("indefinite_array_in_map", "a161619f0102ff", "indefinite-length array")
    add("indefinite_text_in_map", "a161617f626162626364ff", "indefinite-length text")
    add("invalid_utf8_text", "a1616162c0af", "invalid UTF-8 text value")
    add("invalid_utf8_key", "a162c0af01", "invalid UTF-8 map key")
    add("undefined_value", "a16161f7", "undefined")
    add("simple_value", "a16161f0", "simple(16)")
    add("tag1_date_uint", "a16164c11a5f5e1000", "tag 1 epoch date")
    add("tag1_date_text", "a16164c16161", "tag 1 wrapping text (SwiftCBOR throws)")
    add("reserved_info", "1c", "reserved additional info")
    add("truncated_map", "a3616101", "map claims 3 pairs, has 1")
    add("trailing_bytes", "a161610100", "valid map followed by trailing bytes")
    add("type_non_string", "a1652474797065a0", "{$type: {}}")
    add("type_unregistered", "a26178016524747970656a6578616d706c652e7861", "{$type: example.xa, x: 1}")
    add("type_registered_bad", "a2647465787405652474797065726170702e62736b792e666565642e706f7374", "{$type: app.bsky.feed.post, text: 5}")
    add("post_extra_bigint", "a464746578746178652474797065726170702e62736b792e666565642e706f7374666675747572651b8000000000000000696372656174656441747818323032362d30312d30315430303a30303a30302e3030305a", "known post with an unknown field holding 2^63")
    add("post_extra_float", "a464746578746178652474797065726170702e62736b792e666565642e706f737466667574757265fb3fe0000000000000696372656174656441747818323032362d30312d30315430303a30303a30302e3030305a", "known post with an unknown float field")
    add("post_noncanonical", "a3696372656174656441747818323032362d30312d30315430303a30303a30302e3030305a64746578746178652474797065726170702e62736b792e666565642e706f7374", "known post with non-canonical key order")
    add("two_errors_float_and_tag", "a26161fb3ff80000000000006162d82b4100", "two bad entries: which error wins follows dictionary iteration")
    add("deep_array_100", "a161618181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818101", "depth 101 (rejected by preflight)")
    add("deep_map_70", "a16161a1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616ba1616b01", "nested maps depth 71")
    return rows
}

// MARK: - Outcome rendering

/// Structural signature of a dynamic container; known values also expose every dynamic container
/// reachable inside the typed model (Mirror walk), so nested known/unknown classification is covered.
func dagSignature(_ value: ATProtocolValueContainer, stats: inout (known: Int, unknown: Int)) -> String {
    switch value {
    case let .knownType(inner):
        stats.known += 1
        var nested: [String] = []
        dagCollectNested(inner, into: &nested, stats: &stats, depth: 0)
        let json = (try? canonical(inner)).map { String(decoding: $0, as: UTF8.self) } ?? "<json-encode-failed>"
        return "known<\(String(reflecting: type(of: inner)))>\(json)" + (nested.isEmpty ? "" : "{nested:" + nested.joined(separator: ";") + "}")
    case let .unknownType(type, inner):
        stats.unknown += 1
        return "unknown<\(type)>(\(dagSignature(inner, stats: &stats)))"
    case let .object(dict):
        return "{" + dict.keys.sorted().map { "\($0):\(dagSignature(dict[$0]!, stats: &stats))" }.joined(separator: ",") + "}"
    case let .array(items):
        return "[" + items.map { dagSignature($0, stats: &stats) }.joined(separator: ",") + "]"
    case let .string(s): return "s\(s.debugDescription)"
    case let .number(n): return "n\(n)"
    case let .bigNumber(s): return "N\(s)"
    case let .bool(b): return "b\(b)"
    case .null: return "null"
    case let .link(l): return "link(\(l.cid.string))"
    case let .bytes(b): return "bytes(\(b.data.count):\(dagcborFingerprint(b.data)))"
    case let .decodeError(e): return "decodeError(\(e))"
    }
}

func dagCollectNested(_ value: Any, into out: inout [String], stats: inout (known: Int, unknown: Int), depth: Int) {
    if depth > 64 { return }
    if depth > 0, let container = value as? ATProtocolValueContainer {
        out.append(dagSignature(container, stats: &stats))
        return
    }
    for child in Mirror(reflecting: value).children {
        dagCollectNested(child.value, into: &out, stats: &stats, depth: depth + 1)
    }
}

func renderError(_ error: any Error) -> String {
    var text = "\(String(reflecting: type(of: error))): \(String(describing: error))"
    if text.utf8.count > 1500 {
        let data = Data(text.utf8)
        text = "\(String(text.prefix(160)))… [len=\(data.count) fp=\(dagcborFingerprint(data))]"
    }
    return text
}

func renderOutcome(_ body: () throws -> ATProtocolValueContainer, totals: inout (known: Int, unknown: Int)) -> String {
    do {
        let value = try body()
        var stats = (known: 0, unknown: 0)
        let sig = dagSignature(value, stats: &stats)
        totals.known += stats.known; totals.unknown += stats.unknown
        let reenc: String
        do { reenc = dagcborFingerprint(try value.encodedDAGCBOR()) } catch { reenc = "ERR " + renderError(error) }
        let json: String
        do { json = dagcborFingerprint(try canonical(value)) } catch { json = "ERR " + renderError(error) }
        let top: String
        switch value {
        case let .knownType(v): top = "known:\(String(reflecting: type(of: v)))"
        case let .unknownType(t, _): top = "unknown:\(t)"
        case .object: top = "object"
        default: top = "other"
        }
        return "ok top=\(top) known=\(stats.known) unknown=\(stats.unknown) dagcbor=\(reenc) json=\(json) sig=\(sig)"
    } catch {
        return "ERR " + renderError(error)
    }
}

/// Generated `decodedFromDAGCBOR` default (preflight -> SwiftCBOR -> JSON bridge -> JSONCoders).
func typedDAGCBORDecode(collection: String, _ data: Data) throws -> (any Encodable & Sendable)? {
    switch collection {
    case "app.bsky.feed.post": return try AppBskyFeedPost.decodedFromDAGCBOR(data)
    case "app.bsky.feed.like": return try AppBskyFeedLike.decodedFromDAGCBOR(data)
    case "app.bsky.feed.repost": return try AppBskyFeedRepost.decodedFromDAGCBOR(data)
    case "app.bsky.graph.follow": return try AppBskyGraphFollow.decodedFromDAGCBOR(data)
    case "app.bsky.graph.block": return try AppBskyGraphBlock.decodedFromDAGCBOR(data)
    case "app.bsky.actor.profile": return try AppBskyActorProfile.decodedFromDAGCBOR(data)
    default: return nil
    }
}

func collectionOf(_ path: String) -> String { String(path.split(separator: "/").first ?? "") }

// MARK: - Modes

func dagcborDump(_ corpus: DAGCBORCorpus, out: String) throws {
    var lines: [String] = []
    var totalsA = (known: 0, unknown: 0), totalsB = (known: 0, unknown: 0), totalsS = (known: 0, unknown: 0)
    var classA: [String: Int] = [:], typedOK = 0, typedErr = 0
    for (index, (entry, data)) in corpus.blocks.enumerated() {
        let a = renderOutcome({ try ATProtocolValueContainer.decodedFromDAGCBOR(data) }, totals: &totalsA)
        let b = renderOutcome({ try CARRepository.decodeRecordCBOR(data) }, totals: &totalsB)
        // Same bytes behind a non-zero startIndex (slice) must decode identically.
        var padded = Data([0xAA, 0xBB, 0xCC]); padded.append(data)
        let slice = padded[3...]
        let s = renderOutcome({ try ATProtocolValueContainer.decodedFromDAGCBOR(slice) }, totals: &totalsS)
        let top = a.split(separator: " ").dropFirst().first.map(String.init) ?? "err"
        classA[top, default: 0] += 1
        var typed = "n/a"
        do {
            if let model = try typedDAGCBORDecode(collection: collectionOf(entry.path), data) {
                typed = "ok json=\(dagcborFingerprint(try canonical(model)))"; typedOK += 1
            }
        } catch { typed = "ERR " + renderError(error); typedErr += 1 }
        lines.append("R \(index) \(entry.path) \(entry.cid) src=\(entry.source)")
        lines.append("  A \(a)")
        lines.append("  B \(b == a ? "=A" : b)")
        lines.append("  S \(s == a ? "=A" : s)")
        lines.append("  T \(typed)")
    }
    var totalsE = (known: 0, unknown: 0)
    for (name, data) in corpus.edges {
        let a = renderOutcome({ try ATProtocolValueContainer.decodedFromDAGCBOR(data) }, totals: &totalsE)
        let b = renderOutcome({ try CARRepository.decodeRecordCBOR(data) }, totals: &totalsE)
        var pre = "ok"
        do { try DAGCBOR.decodeCBORPreflight(data) } catch { pre = "ERR " + renderError(error) }
        lines.append("E \(name) bytes=\(data.count)")
        lines.append("  A \(a)")
        lines.append("  B \(b)")
        lines.append("  P \(pre)")
    }
    // Whole-CAR path (CARReader + MSTTraverser + decodeRecordCBOR).
    var carLines: [String] = []
    var totalsC = (known: 0, unknown: 0)
    let stats = try CARRepository.parse(fileURL: corpus.carURL) { record in
        var st = (known: 0, unknown: 0)
        let sig = dagSignature(record.value, stats: &st)
        totalsC.known += st.known; totalsC.unknown += st.unknown
        carLines.append("C \(record.collection)/\(record.rkey) \(record.cid.string) raw=\(dagcborFingerprint(record.rawCBOR)) sig=\(dagcborFingerprint(Data(sig.utf8)))")
    }
    lines.append(contentsOf: carLines)
    let summary = "SUMMARY blocks=\(corpus.blocks.count) edges=\(corpus.edges.count) A.known=\(totalsA.known) A.unknown=\(totalsA.unknown) B.known=\(totalsB.known) B.unknown=\(totalsB.unknown) S.known=\(totalsS.known) S.unknown=\(totalsS.unknown) typedOK=\(typedOK) typedErr=\(typedErr) car.records=\(stats.recordCount) car.decoded=\(stats.decodedCount) car.downgraded=\(stats.downgradedCount) car.failed=\(stats.failedCount) car.known=\(totalsC.known) car.unknown=\(totalsC.unknown) topLevel=\(classA.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: ","))"
    lines.append(summary)
    try (lines.joined(separator: "\n") + "\n").write(toFile: out + "/dagcbor-dump.txt", atomically: true, encoding: .utf8)
    progress(summary)
}

enum DAGCBORPath: String, CaseIterable {
    case container, record, car, typed, posts, small, edges, garbage64k, garbage1m, preflight
    /// Harness-only estimate of the typed-first design (see DAGCBORTypedFirstEstimate.swift).
    case tfestimate
    /// Same records as `tfaccepted-legacy`, decoded by the estimate: only blocks the estimate accepts.
    case tfaccepted
    /// Legacy decodedFromDAGCBOR over exactly the blocks `tfaccepted` covers (paired control).
    case tfacceptedLegacy = "tfaccepted-legacy"
}

@inline(never)
func dagcborPass(_ path: DAGCBORPath, _ corpus: DAGCBORCorpus) throws -> Int {
    var checksum = 0
    func note(_ v: ATProtocolValueContainer) {
        switch v {
        case .knownType: checksum &+= 1
        case .unknownType: checksum &+= 1000
        default: checksum &+= 1_000_000
        }
    }
    switch path {
    case .container:
        for (_, data) in corpus.blocks { note(try ATProtocolValueContainer.decodedFromDAGCBOR(data)) }
    case .record:
        for (_, data) in corpus.blocks { note(try CARRepository.decodeRecordCBOR(data)) }
    case .car:
        let stats = try CARRepository.parse(fileURL: corpus.carURL) { note($0.value) }
        checksum &+= stats.recordCount
    case .typed:
        for (entry, data) in corpus.blocks where !entry.source.hasPrefix("edge:") {
            if let m = try? typedDAGCBORDecode(collection: collectionOf(entry.path), data) { withExtendedLifetime(m) { checksum &+= 1 } }
        }
    case .posts:
        for (entry, data) in corpus.blocks where entry.path.hasPrefix("app.bsky.feed.post/") {
            note(try ATProtocolValueContainer.decodedFromDAGCBOR(data))
        }
    case .small:
        for (entry, data) in corpus.blocks where entry.source.hasPrefix("synth:") {
            note(try ATProtocolValueContainer.decodedFromDAGCBOR(data))
        }
    case .edges:
        for (_, data) in corpus.edges where data.count < 4096 {
            if let v = try? ATProtocolValueContainer.decodedFromDAGCBOR(data) { note(v) } else { checksum &+= 7 }
        }
    case .garbage64k, .garbage1m:
        let name = path == .garbage64k ? "garbage_reserved_64k" : "garbage_reserved_1m"
        let data = corpus.edges.first { $0.name == name }!.data
        do { note(try ATProtocolValueContainer.decodedFromDAGCBOR(data)) } catch {
            checksum &+= String(describing: error).utf8.count
        }
    case .preflight:
        for (_, data) in corpus.blocks { try DAGCBOR.decodeCBORPreflight(data); checksum &+= 1 }
    case .tfaccepted, .tfacceptedLegacy:
        for index in dagcborTFAcceptedIndices(corpus) {
            let data = corpus.blocks[index].data
            if path == .tfaccepted {
                guard case let .accepted(v) = try dagcborTypedFirstEstimate(data) else { throw BenchError.message("estimate not deterministic") }
                note(v)
            } else {
                note(try ATProtocolValueContainer.decodedFromDAGCBOR(data))
            }
        }
    case .tfestimate:
        // Accepted records cost the typed-first estimate; fallbacks add the legacy decode they
        // would run (so this is the full cost of the design on the corpus, not a lower bound).
        for (_, data) in corpus.blocks {
            switch try dagcborTypedFirstEstimate(data) {
            case let .accepted(v): note(v)
            case .fallback: note(try ATProtocolValueContainer.decodedFromDAGCBOR(data))
            }
        }
    }
    return checksum
}

nonisolated(unsafe) var dagcborTFAcceptedCache: [Int]?
func dagcborTFAcceptedIndices(_ corpus: DAGCBORCorpus) -> [Int] {
    if let cached = dagcborTFAcceptedCache { return cached }
    var out: [Int] = []
    for (i, block) in corpus.blocks.enumerated() {
        if case .accepted? = try? dagcborTypedFirstEstimate(block.data) { out.append(i) }
    }
    dagcborTFAcceptedCache = out
    return out
}

struct DAGCBORCountRow: Codable {
    let path: String
    let passes: Int
    let checksum: Int
    let mallocsPerPass: [UInt64]
    let mallocBytesPerPass: [UInt64]
    let instructionsPerPass: [UInt64]
    let medianInstructions: UInt64
    let minInstructions: UInt64
}

func dagcborCounts(_ corpus: DAGCBORCorpus, paths: [DAGCBORPath], passes: Int, out: String) throws {
    var rows: [DAGCBORCountRow] = []
    for path in paths {
        var checksum = 0
        for _ in 0 ..< 2 { checksum = try dagcborPass(path, corpus) }
        var mallocs: [UInt64] = [], bytes: [UInt64] = [], instructions: [UInt64] = []
        for _ in 0 ..< passes {
            // Instructions are read without the malloc hook (the hook adds its own instructions).
            let i0 = bench_instructions()
            let c1 = try dagcborPass(path, corpus)
            let i1 = bench_instructions()
            bench_mcount_reset(); bench_mcount_install()
            let c2 = try dagcborPass(path, corpus)
            bench_mcount_uninstall()
            guard c1 == checksum, c2 == checksum else { throw BenchError.message("non-deterministic checksum for \(path)") }
            instructions.append(i1 - i0); mallocs.append(bench_mcount_allocs()); bytes.append(bench_mcount_bytes())
        }
        let sorted = instructions.sorted()
        let row = DAGCBORCountRow(path: path.rawValue, passes: passes, checksum: checksum, mallocsPerPass: mallocs,
                                  mallocBytesPerPass: bytes, instructionsPerPass: instructions,
                                  medianInstructions: sorted[sorted.count / 2], minInstructions: sorted[0])
        rows.append(row)
        progress("COUNTS \(path.rawValue) mallocs=\(mallocs) bytes=\(bytes) instr.median=\(row.medianInstructions) instr.min=\(row.minInstructions) checksum=\(checksum)")
        try save(rows, out + "/dagcbor-counts.json")
    }
}

func dagcborMain(mode: String, args: [String], fixtureDir: String, out: String) async throws {
    func option(_ name: String, _ fallback: String) -> String {
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return fallback }
        return args[i + 1]
    }
    switch mode {
    case "dagcbor-generate":
        try await generateDAGCBORFixture(fixtureDir: fixtureDir)
    case "dagcbor":
        try dagcborDump(try loadDAGCBORCorpus(fixtureDir), out: out)
    case "dagcbor-reenc":
        // Writes input vs typed re-encoding for blocks whose knownType re-encoding differs.
        let corpus = try loadDAGCBORCorpus(fixtureDir)
        var rows: [[String: String]] = []
        for (entry, data) in corpus.blocks {
            let value = try ATProtocolValueContainer.decodedFromDAGCBOR(data)
            guard case .knownType = value, let again = try? value.encodedDAGCBOR(), again != data else { continue }
            rows.append(["path": entry.path, "source": entry.source, "input": hexString(data), "reencoded": hexString(again)])
        }
        try save(rows, out + "/reencoding-diffs.json")
        progress("REENC differing knownType blocks: \(rows.count)")
    case "dagcbor-tf":
        try dagcborTypedFirstAgreement(try loadDAGCBORCorpus(fixtureDir), out: out)
    case "dagcbor-profile":
        let corpus = try loadDAGCBORCorpus(fixtureDir)
        guard let path = DAGCBORPath(rawValue: option("--dagcbor-path", "container")) else { throw BenchError.message("bad --dagcbor-path") }
        let seconds = Double(option("--seconds", "30"))!
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(seconds * 1e9)
        var passes = 0, checksum = 0
        while DispatchTime.now().uptimeNanoseconds < deadline {
            checksum &+= try dagcborPass(path, corpus); passes += 1
        }
        progress("DAGCBOR-PROFILE path=\(path.rawValue) passes=\(passes) checksum=\(checksum)")
    case "dagcbor-counts":
        let corpus = try loadDAGCBORCorpus(fixtureDir)
        let selected = option("--dagcbor-path", "")
        let paths = selected.isEmpty ? DAGCBORPath.allCases : selected.split(separator: ",").compactMap { DAGCBORPath(rawValue: String($0)) }
        try dagcborCounts(corpus, paths: paths, passes: Int(option("--passes", "5"))!, out: out)
    default:
        throw BenchError.message("unknown dagcbor mode \(mode)")
    }
}
