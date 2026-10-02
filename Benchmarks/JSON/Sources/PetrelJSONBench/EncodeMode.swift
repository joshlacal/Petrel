import Foundation
import Petrel
import CBenchMetrics

// --mode encode: Petrel's encode side and Catbird's SwiftData cache round trip.
//
// For every fixture, outside any timer:
//  1. canonical encode: JSONEncoder (.sortedKeys, .withoutEscapingSlashes) of the decoded model,
//     byte-identical to --mode canonical output;
//  2. Catbird-like cache write: plain `JSONEncoder().encode(element)` of each element
//     (CachedFeedViewPost.swift:98 encodes each FeedViewPost this way);
//  3. Catbird-like cache read: `JSONDecoder().decode(Element.self, from:)` of those bytes
//     (CachedFeedViewPost.swift:338).
// Elements are FeedViewPost (timeline), ProfileView (search), listRecords Record (records) or
// the whole Output (profile). Reported deterministically: round-trip stability, typed/unknown
// record classification before and after the round trip, and malloc/instruction counts per
// phase (Darwin, one counted pass after one warm-up pass). Latency is measured only when
// --iterations > 0; deterministic checks always run.

struct EncodePhaseCounters: Codable {
    let mallocs: UInt64
    let mallocBytes: UInt64
    let instructions: UInt64
}

struct EncodeRoundTripRow: Codable {
    let fixture: String
    let elementKind: String
    let elements: Int
    let canonicalBytes: Int
    let canonicalFNV1a64: String
    let catbirdEncodedBytes: Int
    /// canonical(element) == canonical(JSONDecoder().decode(JSONEncoder().encode(element)))
    let roundTripCanonicalEqual: Int
    /// The re-decoded element re-encodes to the same Catbird bytes (second-generation cache write).
    let roundTripBytesStable: Int
    let redecodeErrors: Int
    let typedRecordsBefore: Int
    let unknownRecordsBefore: Int
    let typedRecordsAfter: Int
    let unknownRecordsAfter: Int
    let counters: [String: EncodePhaseCounters]
}

struct EncodeElementRow: Codable {
    let fixture: String
    let index: Int
    let context: String
    let recordsBefore: String
    let recordsAfter: String
    let roundTripCanonicalEqual: Bool
}

private func fnv1a64(_ data: Data) -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in data { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
    return String(format: "%016llx", hash)
}

private func counted(_ body: () throws -> Void) rethrows -> EncodePhaseCounters {
    try body() // warm-up: one-time metadata, caches and lazy globals stay outside the count
    bench_malloc_counting(1)
    let m0 = bench_malloc_count(), b0 = bench_malloc_bytes(), i0 = bench_instructions()
    try body()
    let i1 = bench_instructions(), m1 = bench_malloc_count(), b1 = bench_malloc_bytes()
    bench_malloc_counting(0)
    return EncodePhaseCounters(mallocs: m1 - m0, mallocBytes: b1 - b0, instructions: i1 &- i0)
}

private func recordKinds(_ records: [ATProtocolValueContainer]) -> (typed: Int, unknown: Int, label: String) {
    var typed = 0, unknown = 0
    var labels: [String] = []
    for record in records {
        switch record {
        case .knownType: typed += 1; labels.append("typed")
        case .unknownType: unknown += 1; labels.append("unknown")
        default: labels.append("other")
        }
    }
    return (typed, unknown, labels.joined(separator: ","))
}

private func feedRecords(_ item: AppBskyFeedDefs.FeedViewPost) -> [ATProtocolValueContainer] {
    var records = [item.post.record]
    if let reply = item.reply {
        if case let .appBskyFeedDefsPostView(view) = reply.root { records.append(view.record) }
        if case let .appBskyFeedDefsPostView(view) = reply.parent { records.append(view.record) }
    }
    return records
}

private struct ElementSet<Element: Codable & Sendable> {
    let kind: String
    let elements: [Element]
    let records: (Element) -> [ATProtocolValueContainer]
    let context: (Element) -> String
}

private func encodeFixture<Element: Codable & Sendable>(
    _ fixture: Fixture, model: Model, set: ElementSet<Element>, iterations: Int,
    samples: inout [Sample], details: inout [EncodeElementRow]
) throws -> EncodeRoundTripRow {
    let canonicalBytes = try canonical(model)
    let elements = set.elements
    let encoded = try elements.map { try JSONEncoder().encode($0) }
    var canonicalEqual = 0, bytesStable = 0, errors = 0
    var before = (typed: 0, unknown: 0), after = (typed: 0, unknown: 0)
    for (index, element) in elements.enumerated() {
        let kindsBefore = recordKinds(set.records(element))
        before.typed += kindsBefore.typed; before.unknown += kindsBefore.unknown
        var equal = false
        var afterLabel = "error"
        do {
            let redecoded = try JSONDecoder().decode(Element.self, from: encoded[index])
            equal = try canonical(redecoded) == canonical(element)
            if equal { canonicalEqual += 1 }
            if try JSONEncoder().encode(redecoded) == encoded[index] { bytesStable += 1 }
            let kindsAfter = recordKinds(set.records(redecoded))
            after.typed += kindsAfter.typed; after.unknown += kindsAfter.unknown
            afterLabel = kindsAfter.label
        } catch {
            errors += 1
        }
        if fixture.entry.validator != nil {
            details.append(EncodeElementRow(fixture: fixture.entry.id, index: index, context: set.context(element),
                                            recordsBefore: kindsBefore.label, recordsAfter: afterLabel,
                                            roundTripCanonicalEqual: equal))
        }
    }
    var counters: [String: EncodePhaseCounters] = [:]
    counters["canonicalEncode"] = try counted { _ = try canonical(model) }
    counters["catbirdEncode"] = try counted { for element in elements { _ = try JSONEncoder().encode(element) } }
    counters["catbirdRedecode"] = try counted { for data in encoded { _ = try JSONDecoder().decode(Element.self, from: data) } }

    for iteration in 0 ..< iterations {
        func timed(_ label: String, _ body: () throws -> Void) rethrows {
            let cpu0 = bench_cpu_ns(), t0 = DispatchTime.now().uptimeNanoseconds
            try body()
            let t1 = DispatchTime.now().uptimeNanoseconds, cpu1 = bench_cpu_ns()
            samples.append(Sample(fixture: fixture.entry.id, strategy: label, iteration: iteration, wallNS: t1 - t0, cpuNS: cpu1 - cpu0))
        }
        try timed("encode.canonical") { _ = try canonical(model) }
        try timed("encode.catbirdElements") { for element in elements { _ = try JSONEncoder().encode(element) } }
        try timed("decode.catbirdElements") { for data in encoded { _ = try JSONDecoder().decode(Element.self, from: data) } }
    }

    return EncodeRoundTripRow(
        fixture: fixture.entry.id, elementKind: set.kind, elements: elements.count,
        canonicalBytes: canonicalBytes.count, canonicalFNV1a64: fnv1a64(canonicalBytes),
        catbirdEncodedBytes: encoded.reduce(0) { $0 + $1.count },
        roundTripCanonicalEqual: canonicalEqual, roundTripBytesStable: bytesStable, redecodeErrors: errors,
        typedRecordsBefore: before.typed, unknownRecordsBefore: before.unknown,
        typedRecordsAfter: after.typed, unknownRecordsAfter: after.unknown, counters: counters
    )
}

func encodeMode(_ fixtures: [Fixture], _ iterations: Int, _ out: String) throws {
    var rows: [EncodeRoundTripRow] = []
    var samples: [Sample] = []
    var details: [EncodeElementRow] = []
    for f in fixtures {
        let decoder = JSONDecoder()
        let row: EncodeRoundTripRow
        switch f.entry.modelKind {
        case "timeline":
            let model = try decoder.decode(AppBskyFeedGetTimeline.Output.self, from: f.data)
            row = try encodeFixture(f, model: model, set: ElementSet(kind: "AppBskyFeedDefs.FeedViewPost", elements: model.feed,
                                                                     records: feedRecords, context: { $0.feedContext ?? "" }),
                                    iterations: iterations, samples: &samples, details: &details)
        case "search":
            let model = try decoder.decode(AppBskyActorSearchActors.Output.self, from: f.data)
            row = try encodeFixture(f, model: model, set: ElementSet(kind: "AppBskyActorDefs.ProfileView", elements: model.actors,
                                                                     records: { _ in [] }, context: { "\($0.handle)" }),
                                    iterations: iterations, samples: &samples, details: &details)
        case "profile":
            let model = try decoder.decode(AppBskyActorGetProfile.Output.self, from: f.data)
            row = try encodeFixture(f, model: model, set: ElementSet(kind: "AppBskyActorGetProfile.Output", elements: [model],
                                                                     records: { _ in [] }, context: { "\($0.handle)" }),
                                    iterations: iterations, samples: &samples, details: &details)
        case "records":
            let model = try decoder.decode(ComAtprotoRepoListRecords.Output.self, from: f.data)
            row = try encodeFixture(f, model: model, set: ElementSet(kind: "ComAtprotoRepoListRecords.Record", elements: model.records,
                                                                     records: { [$0.value] }, context: { $0.uri.uriString() }),
                                    iterations: iterations, samples: &samples, details: &details)
        default:
            throw BenchError.message("Unknown model kind \(f.entry.modelKind)")
        }
        rows.append(row)
        let phases = row.counters.keys.sorted().map { key in
            let c = row.counters[key]!
            return "\(key) mallocs=\(c.mallocs) instr=\(c.instructions)"
        }.joined(separator: "; ")
        progress("ENCODE \(row.fixture) elements=\(row.elements) canonical=\(row.canonicalBytes)B/\(row.canonicalFNV1a64) catbird=\(row.catbirdEncodedBytes)B roundTripEqual=\(row.roundTripCanonicalEqual)/\(row.elements) bytesStable=\(row.roundTripBytesStable) errors=\(row.redecodeErrors) records typed/unknown before=\(row.typedRecordsBefore)/\(row.unknownRecordsBefore) after=\(row.typedRecordsAfter)/\(row.unknownRecordsAfter) | \(phases)")
    }
    try save(rows, out + "/encode-roundtrip.json")
    if !details.isEmpty { try save(details, out + "/encode-elements.json") }
    if iterations > 0 {
        try save(samples, out + "/encode-samples.json")
        var summaries: [Summary] = []
        for f in fixtures {
            for label in ["encode.canonical", "encode.catbirdElements", "decode.catbirdElements"] {
                let rows = samples.filter { $0.fixture == f.entry.id && $0.strategy == label }
                if !rows.isEmpty {
                    let s = summary(rows, bytes: f.data.count)
                    summaries.append(s)
                    progress("RESULT \(s.fixture) \(s.strategy) median \(s.medianMS) ms p95 \(s.p95MS)")
                }
            }
        }
        try save(summaries, out + "/encode-summary.json")
    }
}
