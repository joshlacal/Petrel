import Foundation
@_spi(XRPCDecodeExperimental) import Petrel
import CBenchMetrics

// Correctness gate for the opt-in parallel array decode (no latency timing).
//
//   --mode parallelgate [--fixtures DIR] [--mutations N] [--out DIR]
//
// 1. Chunk/worker sweep: every eligible fixture decoded through the parallel overload with the
//    thresholds forced to zero, at chunk counts 1...32 (and a worker grid), must re-encode to the
//    same canonical bytes as a fresh sequential JSONDecoder decode. The parallel path must actually
//    run (statistics delta), never fall back.
// 2. Outcome equivalence on malformed / unusual documents: named variants plus deterministic random
//    mutations of each eligible fixture. Accepted values must re-encode identically; rejected
//    documents must throw an error whose full reflection (case, coding path, debug description,
//    underlying error) equals the sequential decoder's. Run with SWIFT_DETERMINISTIC_HASHING=1:
//    a sequential-vs-sequential control detects documents whose error is inherently hash-order
//    dependent, and those are compared by error type only.
// 3. Cancellation: a cancelled task gets CancellationError from both overloads before any decode;
//    the switch turns that off.
// 4. Deterministic counters: instructions retired per decode (proc_pid_rusage), sequential vs parallel.

private struct GateRow: Codable {
    let section: String
    let fixture: String
    let variant: String
    let status: String
    let detail: String
}

private enum Outcome: Equatable {
    case accepted(Data)
    case rejected(type: String, reflection: String)

    var label: String {
        switch self {
        case .accepted: return "accepted"
        case let .rejected(type, _): return "rejected(\(type))"
        }
    }
}

private func outcome(_ body: () async throws -> Model) async -> Outcome {
    do {
        return try await .accepted(canonical(body()))
    } catch {
        return .rejected(type: String(reflecting: type(of: error)), reflection: String(reflecting: error))
    }
}

private func sequentialDecode(_ kind: String, _ data: Data) throws -> Model {
    switch kind {
    case "search": return try JSONDecoder().decode(AppBskyActorSearchActors.Output.self, from: data)
    case "timeline": return try JSONDecoder().decode(AppBskyFeedGetTimeline.Output.self, from: data)
    case "records": return try JSONDecoder().decode(ComAtprotoRepoListRecords.Output.self, from: data)
    case "profile": return try JSONDecoder().decode(AppBskyActorGetProfile.Output.self, from: data)
    default: throw BenchError.message("Unknown model kind \(kind)")
    }
}

private func parallelDecode(_ kind: String, _ data: Data, _ configuration: XRPCResponseDecoding.Configuration) async throws -> Model {
    try await XRPCResponseDecoding.configurationOverride.withValue(configuration) {
        switch kind {
        case "search": return try await XRPCResponseDecoding.decode(AppBskyActorSearchActors.Output.self, from: data, endpoint: "gate")
        case "timeline": return try await XRPCResponseDecoding.decode(AppBskyFeedGetTimeline.Output.self, from: data, endpoint: "gate")
        case "records": return try await XRPCResponseDecoding.decode(ComAtprotoRepoListRecords.Output.self, from: data, endpoint: "gate")
        case "profile": return try await XRPCResponseDecoding.decode(AppBskyActorGetProfile.Output.self, from: data, endpoint: "gate")
        default: throw BenchError.message("Unknown model kind \(kind)")
        }
    }
}

private func forced(chunks: Int?, workers: Int? = nil) -> XRPCResponseDecoding.Configuration {
    XRPCResponseDecoding.Configuration(
        parallelArrayDecoding: true,
        parallelMinimumBytes: 0,
        parallelMinimumElements: 0,
        parallelChunkCount: chunks,
        parallelMaximumWorkers: workers
    )
}

private struct GateRNG {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state >> 11
    }

    mutating func below(_ n: Int) -> Int { Int(next() % UInt64(max(1, n))) }
}

private func replacingFirst(_ text: String, _ target: String, _ replacement: String) -> String {
    guard let range = text.range(of: target) else { return text }
    return text.replacingCharacters(in: range, with: replacement)
}

private func namedVariants(_ fixture: Fixture) -> [(String, Data)] {
    let data = fixture.data
    let text = String(decoding: data, as: UTF8.self)
    let key: String = switch fixture.entry.modelKind {
    case "timeline": "feed"
    case "search": "actors"
    default: "records"
    }
    let quotedKey = "\"\(key)\":["
    var variants: [(String, Data)] = []
    func add(_ name: String, _ string: String) { variants.append((name, Data(string.utf8))) }
    add("unchanged", text)
    add("truncated_tail", String(text.dropLast(10)))
    add("truncated_mid_array", String(text.prefix(text.utf8.count / 2)))
    add("garbage_after_root", text + " ]")
    add("trailing_whitespace", text + " \n\t\r ")
    add("leading_whitespace", " \n\t\r " + text)
    add("bom_prefix", "\u{FEFF}" + text)
    add("garbage_between_elements", replacingFirst(text, "},{", "},,{"))
    add("missing_comma_between_elements", replacingFirst(text, "},{", "}{"))
    add("bracket_kind_mismatch", replacingFirst(text, "]},{", "}},{"))
    add("array_null", replacingFirst(text, quotedKey, "\"\(key)\":null,\"x\":["))
    add("array_missing", replacingFirst(text, "\"\(key)\":", "\"x\(key)\":"))
    add("array_empty_replaced", replacingFirst(text, quotedKey, "\"\(key)\":[],\"\(key)_old\":["))
    add("escaped_array_key", replacingFirst(text, quotedKey, "\"\(key.dropLast())\\u00\(String(key.utf8.last!, radix: 16))\":["))
    add("duplicate_array_key_appended", String(text.dropLast()) + ",\"\(key)\":[]}")
    add("duplicate_array_key_prepended", "{\"\(key)\":[]," + text.dropFirst())
    add("non_ascii_unrelated_key_prepended", "{\"k\u{00E9}y\":1," + text.dropFirst())
    add("cursor_wrong_type", replacingFirst(text, "\"cursor\":\"", "\"cursor\":42,\"oldCursor\":\""))
    add("first_element_not_object", replacingFirst(text, quotedKey, quotedKey + "1,"))
    add("first_element_null", replacingFirst(text, quotedKey, quotedKey + "null,"))
    add("first_element_empty_object", replacingFirst(text, quotedKey, quotedKey + "{},"))
    add("element_nested_deep_600", replacingFirst(text, quotedKey, quotedKey + "{\"deep\":" + String(repeating: "[", count: 600) + String(repeating: "]", count: 600) + "},"))
    add("element_nested_deep_505", replacingFirst(text, quotedKey, quotedKey + "{\"deep\":" + String(repeating: "[", count: 505) + String(repeating: "]", count: 505) + "},"))
    add("element_invalid_escape", replacingFirst(text, "\"did\":\"did:", "\"did\":\"\\qdid:"))
    add("element_lone_surrogate", replacingFirst(text, "\"did\":\"did:", "\"did\":\"\\uD800did:"))
    add("element_control_char", replacingFirst(text, "\"did\":\"did:", "\"did\":\"\u{01}did:"))
    add("element_int_overflow", replacingFirst(text, "Count\":", "Count\":9223372036854775808,\"oldCount\":"))
    add("element_huge_number", replacingFirst(text, "Count\":", "Count\":1e400,\"oldCount\":"))
    add("element_fractional_int", replacingFirst(text, "Count\":", "Count\":1.5,\"oldCount\":"))
    add("element_missing_required_cid", {
        guard let range = text.range(of: #""cid":"[^"]*","#, options: .regularExpression) else { return text }
        return text.replacingCharacters(in: range, with: "")
    }())
    add("element_duplicate_inner_key", replacingFirst(text, "\"did\":\"did:", "\"did\":\"did:plc:dup\",\"did\":\"did:"))
    add("element_unknown_field", replacingFirst(text, quotedKey + "{", quotedKey + "{\"futureField\":{\"a\":[1,2,{\"b\":null}]},"))
    add("whitespace_between_elements", text.replacingOccurrences(of: "},{", with: "} ,\n\t{"))
    var variantsWithBytes = variants
    // Raw invalid UTF-8 byte inside the first element.
    var bytes = Array(data)
    if let keyRange = text.range(of: quotedKey) {
        let offset = text.utf8.distance(from: text.startIndex, to: keyRange.upperBound)
        if let i = bytes[offset...].firstIndex(of: UInt8(ascii: "h")) { bytes[i] = 0xFF }
    }
    variantsWithBytes.append(("element_invalid_utf8_byte", Data(bytes)))
    // UTF-16 encoded document (Foundation detects and decodes it; the splitter must decline).
    if data.count < 600_000, let utf16 = text.data(using: .utf16BigEndian) {
        variantsWithBytes.append(("utf16be_document", utf16))
    }
    return variantsWithBytes
}

private func randomMutation(_ data: Data, _ rng: inout GateRNG) -> (String, Data) {
    var bytes = Array(data)
    let alphabet = Array("{}[],:\"\\ 0123456789aex-.".utf8) + [0xFF, 0x00, 0x0A]
    let position = rng.below(bytes.count)
    switch rng.below(6) {
    case 0:
        bytes.remove(at: position)
        return ("delete@\(position)", Data(bytes))
    case 1:
        let b = alphabet[rng.below(alphabet.count)]
        bytes.insert(b, at: position)
        return ("insert\(b)@\(position)", Data(bytes))
    case 2:
        let b = alphabet[rng.below(alphabet.count)]
        bytes[position] = b
        return ("replace\(b)@\(position)", Data(bytes))
    case 3:
        let length = 1 + rng.below(64)
        let end = min(bytes.count, position + length)
        bytes.insert(contentsOf: bytes[position ..< end], at: position)
        return ("dup\(length)@\(position)", Data(bytes))
    case 4:
        let other = rng.below(bytes.count)
        bytes.swapAt(position, other)
        return ("swap@\(position),\(other)", Data(bytes))
    default:
        let length = 1 + rng.below(256)
        let end = min(bytes.count, position + length)
        bytes.removeSubrange(position ..< end)
        return ("cut\(length)@\(position)", Data(bytes))
    }
}

func parallelGate(_ fixtures: [Fixture], _ out: String, mutations mutationsPerFixture: Int, instructionRounds rounds: Int) async throws {
    var rows: [GateRow] = []
    var failures = 0
    let deterministic = ProcessInfo.processInfo.environment["SWIFT_DETERMINISTIC_HASHING"] != nil
    progress("GATE deterministicHashing=\(deterministic) activeProcessors=\(ProcessInfo.processInfo.activeProcessorCount)")
    let eligible = fixtures.filter { ["timeline", "search", "records"].contains($0.entry.modelKind) }

    // 1. Chunk and worker sweep.
    var sweepCells = 0
    for fixture in eligible {
        let reference = try canonical(sequentialDecode(fixture.entry.modelKind, fixture.data))
        var grid: [(Int?, Int?)] = (1 ... 32).map { ($0, nil) }
        grid.append((nil, nil))
        for workers in [1, 2, 3, 4, 8, 16] {
            for chunks in [1, 2, 5, 32] { grid.append((chunks, workers)) }
        }
        var mismatches = 0
        for (chunks, workers) in grid {
            let before = XRPCResponseDecoding.statistics()
            let value = try await canonical(parallelDecode(fixture.entry.modelKind, fixture.data, forced(chunks: chunks, workers: workers)))
            let after = XRPCResponseDecoding.statistics()
            let ranParallel = after.parallelDecodes == before.parallelDecodes + 1 && after.fallbacksAfterFailure == before.fallbacksAfterFailure
            sweepCells += 1
            if value != reference || !ranParallel {
                mismatches += 1
                failures += 1
                rows.append(GateRow(section: "sweep", fixture: fixture.entry.id, variant: "chunks=\(chunks.map(String.init) ?? "auto") workers=\(workers.map(String.init) ?? "auto")", status: "FAIL", detail: "canonicalEqual=\(value == reference) ranParallel=\(ranParallel)"))
            }
        }
        rows.append(GateRow(section: "sweep", fixture: fixture.entry.id, variant: "\(grid.count) cells", status: mismatches == 0 ? "pass" : "FAIL", detail: "chunks 1...32 + auto + worker grid; canonical bytes vs sequential; parallel path taken in every cell"))
        progress("SWEEP \(fixture.entry.id) cells=\(grid.count) mismatches=\(mismatches)")
    }

    // 2. Outcome equivalence on named variants and random mutations.
    var tally: [String: Int] = [:]
    for fixture in eligible {
        var cases = namedVariants(fixture)
        var rng = GateRNG(state: 0x5EED_0000 &+ fixture.entry.id.utf8.reduce(UInt64(0)) { $0 &* 31 &+ UInt64($1) })
        let count = fixture.data.count > 2_000_000 ? max(10, mutationsPerFixture / 10) : mutationsPerFixture
        for _ in 0 ..< count { cases.append(randomMutation(fixture.data, &rng)) }
        var fixtureFailures = 0
        for (name, data) in cases {
            let kind = fixture.entry.modelKind
            let sequential = await outcome { try sequentialDecode(kind, data) }
            let control = await outcome { try sequentialDecode(kind, data) }
            let hashOrderDependent = sequential != control
            for chunks in [1, 4, 32] {
                let before = XRPCResponseDecoding.statistics()
                let parallel = await outcome { try await parallelDecode(kind, data, forced(chunks: chunks)) }
                let after = XRPCResponseDecoding.statistics()
                let path = after.parallelDecodes > before.parallelDecodes ? "parallel"
                    : after.fallbacksAfterFailure > before.fallbacksAfterFailure ? "fallback"
                    : after.splitterDeclined > before.splitterDeclined ? "declined" : "other"
                tally["\(path)/\(sequential.label.hasPrefix("accepted") ? "accepted" : "rejected")", default: 0] += 1
                let equal: Bool
                if hashOrderDependent {
                    equal = { if case let .rejected(a, _) = sequential, case let .rejected(b, _) = parallel { return a == b }; return false }()
                } else {
                    equal = sequential == parallel
                }
                if !equal {
                    fixtureFailures += 1
                    failures += 1
                    rows.append(GateRow(section: "outcome", fixture: fixture.entry.id, variant: "\(name) chunks=\(chunks)", status: "FAIL", detail: "sequential=\(sequential.label) parallel=\(parallel.label) path=\(path)"))
                }
                if path == "parallel", case .rejected = parallel {
                    // A parallel success can never be a rejection; guard the bookkeeping itself.
                    fixtureFailures += 1
                    failures += 1
                    rows.append(GateRow(section: "outcome", fixture: fixture.entry.id, variant: "\(name) chunks=\(chunks)", status: "FAIL", detail: "parallel path recorded but outcome rejected"))
                }
                if chunks == 1, !name.contains("@") {
                    rows.append(GateRow(section: "outcome", fixture: fixture.entry.id, variant: name, status: equal ? "pass" : "FAIL", detail: "sequential=\(sequential.label) path=\(path)\(hashOrderDependent ? " hashOrderDependent" : "")"))
                }
            }
        }
        progress("OUTCOME \(fixture.entry.id) cases=\(cases.count) x3 chunkings failures=\(fixtureFailures)")
    }
    progress("OUTCOME-PATHS \(tally.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " "))")

    // 3. Cancellation.
    func cancelledOutcome(_ configuration: XRPCResponseDecoding.Configuration, parallelOverload: Bool, data: Data) async -> String {
        let task = Task { () -> String in
            withUnsafeCurrentTask { $0?.cancel() }
            do {
                let value: Model = try await XRPCResponseDecoding.configurationOverride.withValue(configuration) {
                    if parallelOverload {
                        return try await XRPCResponseDecoding.decode(AppBskyFeedGetTimeline.Output.self, from: data, endpoint: "gate")
                    }
                    return try await entryDecode(AppBskyFeedGetTimeline.Output.self, data, endpoint: "gate")
                }
                return "decoded(\((value as! AppBskyFeedGetTimeline.Output).feed.count))"
            } catch is CancellationError {
                return "CancellationError"
            } catch {
                return "other(\(error))"
            }
        }
        return await task.value
    }
    if let timeline = eligible.first(where: { $0.entry.modelKind == "timeline" }) {
        let expectedCount = try (sequentialDecode("timeline", timeline.data) as! AppBskyFeedGetTimeline.Output).feed.count
        let checks: [(String, XRPCResponseDecoding.Configuration, Bool, String)] = [
            ("general overload, check on", .standard, false, "CancellationError"),
            ("parallel overload, parallel off, check on", .standard, true, "CancellationError"),
            ("parallel overload, parallel on, check on", forced(chunks: nil), true, "CancellationError"),
            ("general overload, check off", XRPCResponseDecoding.Configuration(checksCancellationBeforeDecode: false), false, "decoded(\(expectedCount))"),
            ("parallel overload, parallel on, check off", { var c = forced(chunks: nil); c.checksCancellationBeforeDecode = false; return c }(), true, "decoded(\(expectedCount))"),
        ]
        for (name, configuration, parallelOverload, expected) in checks {
            let before = XRPCResponseDecoding.statistics()
            let actual = await cancelledOutcome(configuration, parallelOverload: parallelOverload, data: timeline.data)
            let after = XRPCResponseDecoding.statistics()
            let decodedNothing = expected != "CancellationError" || after == before
            let pass = actual == expected && decodedNothing
            if !pass { failures += 1 }
            rows.append(GateRow(section: "cancellation", fixture: timeline.entry.id, variant: name, status: pass ? "pass" : "FAIL", detail: "expected=\(expected) actual=\(actual) statisticsUnchanged=\(after == before)"))
            progress("CANCEL \(name): \(actual) \(pass ? "pass" : "FAIL")")
        }
        // Not cancelled: both overloads decode.
        let live = try await canonical(parallelDecode("timeline", timeline.data, .standard))
        let reference = try canonical(sequentialDecode("timeline", timeline.data))
        let pass = live == reference
        if !pass { failures += 1 }
        rows.append(GateRow(section: "cancellation", fixture: timeline.entry.id, variant: "not cancelled", status: pass ? "pass" : "FAIL", detail: "decoded through the entry with the standard configuration"))
    }

    // 4. Instructions retired per decode (process-wide, all threads).
    struct InstructionRow: Codable { let fixture: String; let sequential: UInt64; let entry: UInt64; let parallelAuto: UInt64; let parallelChunks: [String: UInt64] }
    var instructionRows: [InstructionRow] = []
    for fixture in fixtures {
        let kind = fixture.entry.modelKind
        func measure(_ body: () async throws -> Model) async throws -> UInt64 {
            _ = try await body()
            let i0 = bench_instructions()
            for _ in 0 ..< rounds {
                let value = try await body()
                withExtendedLifetime(value) {}
            }
            return (bench_instructions() &- i0) / UInt64(rounds)
        }
        let sequential = try await measure { try sequentialDecode(kind, fixture.data) }
        let entry = try await measure { try await decodeAsync(fixture, Context(.foundationEntry)) }
        let auto = try await measure { try await parallelDecode(kind, fixture.data, forced(chunks: nil)) }
        var perChunk: [String: UInt64] = [:]
        for chunks in [1, 4, 16, 32] {
            perChunk[String(chunks)] = try await measure { try await parallelDecode(kind, fixture.data, forced(chunks: chunks)) }
        }
        instructionRows.append(InstructionRow(fixture: fixture.entry.id, sequential: sequential, entry: entry, parallelAuto: auto, parallelChunks: perChunk))
        progress("INSTR \(fixture.entry.id) sequential=\(sequential) entry=\(entry) parallelAuto=\(auto) chunks=\(perChunk.sorted { Int($0.key)! < Int($1.key)! }.map { "\($0.key):\($0.value)" }.joined(separator: ","))")
    }

    try save(rows, out + "/parallel-gate.json")
    try save(instructionRows, out + "/parallel-instructions.json")
    progress(parallelStatisticsLine())
    progress("GATE sweepCells=\(sweepCells) failures=\(failures)")
    guard failures == 0 else { throw BenchError.message("parallel gate failed: \(failures) failure(s); see \(out)/parallel-gate.json") }
}
