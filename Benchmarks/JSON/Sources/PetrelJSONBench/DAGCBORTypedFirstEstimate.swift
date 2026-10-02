import Foundation
import Petrel
import PetrelCore
import SwiftCBOR

// Harness-only ESTIMATE of the CBOR "typed-first" design (not a Petrel change).
// Decodes the root record type once from the UNRESOLVED raw tree, then runs one fidelity
// comparison, instead of legacy fromCBOR's bottom-up resolution (every nested $type decoded,
// re-encoded and compared, and re-decoded again through each parent's union). The guard is the
// conservative one from the design note: every nested raw object carrying a string $type must
// line up with a typed-view object carrying the identical $type, otherwise the record falls back.

/// Mirror of fromCBOR's parse phase (same scalar rules, same $link/$bytes collapse and errors),
/// with no $type resolution.
func dagcborRawParse(_ item: CBOR, stringify: Bool) throws -> ATProtocolValueContainer {
    switch item {
    case let .utf8String(s): return .string(s)
    case let .unsignedInt(u):
        if u <= UInt64(Int.max) { return .number(Int(u)) }
        if stringify { return .string(String(u)) }
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unsigned integer \(u) exceeds the signed 64-bit integer range"))
    case let .negativeInt(a):
        guard a <= UInt64(Int64.max) else { throw DAGCBORError.decodingFailed("CBOR negative integer argument exceeds the Int64 decoding boundary") }
        return .number(Int(-Int64(a) - 1))
    case let .boolean(b): return .bool(b)
    case .null: return .null
    case let .byteString(b): return .bytes(Bytes(data: Data(b)))
    case let .tagged(tag, value):
        guard tag.rawValue == 42 else { throw DAGCBORError.unsupportedType("Unsupported CBOR tag: \(tag.rawValue)") }
        guard case let .byteString(b) = value, b.count > 0, b[0] == 0 else { throw DAGCBORError.invalidCIDEncoding("Tag 42 payload must be bytes starting with 0x00") }
        return .link(ATProtoLink(cid: try CID(bytes: Data(b.dropFirst()))))
    case let .array(items): return .array(try items.map { try dagcborRawParse($0, stringify: stringify) })
    case let .map(dict):
        var out = [String: ATProtocolValueContainer]()
        out.reserveCapacity(dict.count)
        for (k, v) in dict {
            guard case let .utf8String(key) = k else { throw DAGCBORError.invalidMapKey }
            out[key] = try dagcborRawParse(v, stringify: stringify)
        }
        if out.count == 1 {
            if let l = out["$link"] {
                guard case let .string(s) = l else { throw DAGCBORError.decodingFailed("Invalid $link value; expected string") }
                return .link(ATProtoLink(cid: try CID.parse(s)))
            }
            if let b = out["$bytes"] {
                guard case let .string(s) = b else { throw DAGCBORError.decodingFailed("Invalid $bytes value; expected base64 string") }
                guard let d = Data(base64Encoded: s) else { throw DAGCBORError.decodingFailed("Invalid base64 in exact $bytes object") }
                return .bytes(Bytes(data: d))
            }
        }
        return .object(out)
    default:
        throw DAGCBORError.unsupportedType("Unsupported CBOR type encountered during decoding: \(item)")
    }
}

/// Conservative nested-$type guard: walks typed view vs raw; any raw object with a string $type
/// below the root must face a typed object with the same $type.
nonisolated(unsafe) var dagcborGuardFailure = ""

func dagcborNestedTypeGuard(typed: ATProtocolValueContainer, raw: ATProtocolValueContainer, isRoot: Bool, path: String = "") -> Bool {
    switch raw {
    case let .object(r):
        if !isRoot, case let .string(rt)? = r["$type"] {
            guard case let .object(t) = typed, t["$type"] == r["$type"] else {
                var tt = "non-object"
                if case let .object(t) = typed { tt = t["$type"].map { "\($0)" } ?? "no-$type" }
                dagcborGuardFailure = "\(path) raw=\(rt) typedView=\(tt)"
                return false
            }
        }
        guard case let .object(t) = typed else { return true }
        for (k, tv) in t { if let rv = r[k], !dagcborNestedTypeGuard(typed: tv, raw: rv, isRoot: false, path: path + "/" + k) { return false } }
        return true
    case let .array(r):
        guard case let .array(t) = typed, t.count == r.count else { return true }
        for (i, (tv, rv)) in zip(t, r).enumerated() where !dagcborNestedTypeGuard(typed: tv, raw: rv, isRoot: false, path: path + "/\(i)") { return false }
        return true
    default:
        return true
    }
}

enum DAGCBORTypedFirstOutcome { case accepted(ATProtocolValueContainer), fallback(String) }

func dagcborTypedFirstEstimate(_ data: Data) throws -> DAGCBORTypedFirstOutcome {
    guard let item = try? CBOR.decode([UInt8](data)) else { return .fallback("cbor") }
    let raw = try dagcborRawParse(item, stringify: false)
    guard case let .object(dict) = raw, case let .string(t)? = dict["$type"] else { return .fallback("no-type") }
    let decoder = ATProtocolValueContainerDecoder(value: raw)
    let value: any ATProtocolValue
    do {
        switch t {
        case "app.bsky.feed.post": value = try AppBskyFeedPost(from: decoder)
        case "app.bsky.feed.like": value = try AppBskyFeedLike(from: decoder)
        case "app.bsky.feed.repost": value = try AppBskyFeedRepost(from: decoder)
        case "app.bsky.graph.follow": value = try AppBskyGraphFollow(from: decoder)
        case "app.bsky.graph.block": value = try AppBskyGraphBlock(from: decoder)
        case "app.bsky.actor.profile": value = try AppBskyActorProfile(from: decoder)
        default: return .fallback("type-not-in-estimate")
        }
    } catch { return .fallback("typed-decode-threw") }
    let typed = ATProtocolValueContainer.knownType(value)
    guard let cbor = try? value.toCBORValue() else { return .fallback("encode") }
    let view = ATProtocolValueContainer.containerFromCBORValue(cbor)
    guard dagcborNestedTypeGuard(typed: view, raw: raw, isRoot: true) else { return .fallback("nested-type-guard") }
    // `view` is already the typed side's container: pass it (not `.knownType`) so the public
    // comparator does not re-encode the typed value a second time.
    guard ATProtocolValueContainer.isSpecTolerantMatch(typed: view, raw: raw) else { return .fallback("fidelity") }
    return .accepted(typed)
}

/// Agreement of the estimate with the production path on every record block.
func dagcborTypedFirstAgreement(_ corpus: DAGCBORCorpus, out: String) throws {
    var accepted = 0, agree = 0, disagree: [String] = [], fallbacks: [String: Int] = [:], guardDetail: [String: Int] = [:]
    for (entry, data) in corpus.blocks {
        let legacy = try ATProtocolValueContainer.decodedFromDAGCBOR(data)
        switch try dagcborTypedFirstEstimate(data) {
        case let .fallback(reason):
            fallbacks[reason, default: 0] += 1
            if reason == "nested-type-guard" { guardDetail[dagcborGuardFailure.replacingOccurrences(of: #"/\d+"#, with: "/#", options: .regularExpression), default: 0] += 1 }
        case let .accepted(value):
            accepted += 1
            var s1 = (known: 0, unknown: 0), s2 = (known: 0, unknown: 0)
            let same = dagSignature(value, stats: &s1) == dagSignature(legacy, stats: &s2)
                && (try? value.encodedDAGCBOR()) == (try? legacy.encodedDAGCBOR())
                && (try? canonical(value)) == (try? canonical(legacy))
            if same { agree += 1 } else { disagree.append("\(entry.path) \(entry.source)") }
        }
    }
    let summary = "TF-ESTIMATE blocks=\(corpus.blocks.count) accepted=\(accepted) agreeWithLegacy=\(agree) disagree=\(disagree.count) fallbacks=\(fallbacks.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: ","))"
    let guards = guardDetail.sorted { $0.value > $1.value }.map { "GUARD \($0.value) \($0.key)" }
    for g in guards { progress("  \(g)") }
    try ([summary] + disagree.map { "DISAGREE \($0)" } + guards).joined(separator: "\n").write(toFile: out + "/typedfirst-estimate.txt", atomically: true, encoding: .utf8)
    progress(summary)
    for d in disagree.prefix(20) { progress("  DISAGREE \(d)") }
}
