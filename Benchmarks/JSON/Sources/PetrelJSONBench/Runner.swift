import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
#if canImport(FoundationEssentials)
import FoundationEssentials
#endif
import Petrel
import PetrelCore
import SimdUTF
import CBenchMetrics
#if canImport(ZippyJSON)
import ZippyJSON
#endif

func progress(_ text: String) { print(text); fflush(nil) }

struct FixtureEntry: Decodable, Sendable {
    let id: String
    let file: String
    let modelKind: String
    let bytes: Int
    let sha256: String
    /// Manifest expectations; optional so older manifests still decode.
    let expectedTopLevelCounts: [String: Int]?
    /// Selects a fixture-specific corpus validator (e.g. "fidelity-edge").
    let validator: String?
}
struct Manifest: Decodable { let fixtures: [FixtureEntry] }
struct Fixture: Sendable { let entry: FixtureEntry; let data: Data }
enum Strategy: String, CaseIterable, Sendable {
    case foundationFresh, foundationReuse, foundationLocked, foundationEssentials
    case zippy = "zippyCompat"
    case simdCodable, simdDirect, foundationSpecialized
    static var available: [Strategy] {
        var cases = allCases
        #if !canImport(ZippyJSON)
        cases.removeAll { $0 == .zippy }
        #endif
        #if !canImport(FoundationEssentials)
        cases.removeAll { $0 == .foundationEssentials }
        #endif
        return cases
    }
}
final class Context {
    let strategy: Strategy
    let decoder = JSONDecoder()
    #if canImport(ZippyJSON)
    let zippy = ZippyJSONDecoder()
    #endif
    init(_ strategy: Strategy) { self.strategy = strategy }
    func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        switch strategy {
        case .foundationFresh, .foundationSpecialized: return try JSONDecoder().decode(type, from: data)
        case .foundationReuse: return try decoder.decode(type, from: data)
        case .foundationLocked: return try JSONCoders.decode(type, from: data)
        case .foundationEssentials:
            #if canImport(FoundationEssentials)
            return try FoundationEssentials.JSONDecoder().decode(type, from: data)
            #else
            throw BenchError.message("FoundationEssentials not separately importable in Apple SDK")
            #endif
        case .zippy:
            #if canImport(ZippyJSON)
            return try zippy.decode(type, from: data)
            #else
            throw BenchError.message("ZippyJSON requires Darwin Objective-C")
            #endif
        case .simdCodable, .simdDirect: return try SIMDModelDecoder().decode(type, from: data)
        }
    }
}
enum BenchError: Error { case message(String) }
typealias Model = any Encodable & Sendable
@inline(never) func decode(_ fixture: Fixture, _ context: Context) throws -> Model {
    switch fixture.entry.modelKind {
    case "profile": return try context.decode(AppBskyActorGetProfile.Output.self, fixture.data)
    case "search": return try context.decode(AppBskyActorSearchActors.Output.self, fixture.data)
    case "timeline":
        if context.strategy == .foundationSpecialized { return try directFoundationTimeline(fixture.data) }
        if context.strategy == .simdDirect { return try directTimeline(fixture.data) }
        return try context.decode(AppBskyFeedGetTimeline.Output.self, fixture.data)
    case "records": return try context.decode(ComAtprotoRepoListRecords.Output.self, fixture.data)
    default: throw BenchError.message("Unknown model kind \(fixture.entry.modelKind)")
    }
}
func canonical(_ model: Model) throws -> Data {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(model)
}
struct Sample: Codable, Sendable {
    let fixture: String; let strategy: String; let iteration: Int
    let wallNS: UInt64; let cpuNS: UInt64
}
struct Summary: Codable {
    let fixture: String; let strategy: String; let bytes: Int; let count: Int
    let medianMS: Double; let p95MS: Double; let stddevMS: Double; let minMS: Double; let maxMS: Double
    let medianCPUms: Double; let mbps: Double
}
func percentile(_ values: [Double], _ q: Double) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted(); return sorted[min(sorted.count - 1, Int(ceil(q * Double(sorted.count))) - 1)]
}
func summary(_ samples: [Sample], bytes: Int) -> Summary {
    let times = samples.map { Double($0.wallNS) / 1e6 }
    let mean = times.reduce(0,+) / Double(times.count)
    let sd = sqrt(times.map { ($0-mean)*($0-mean) }.reduce(0,+) / Double(max(1,times.count-1)))
    let median = percentile(times,0.5)
    return Summary(fixture:samples[0].fixture,strategy:samples[0].strategy,bytes:bytes,count:samples.count,
      medianMS:median,p95MS:percentile(times,0.95),stddevMS:sd,minMS:times.min()!,maxMS:times.max()!,
      medianCPUms:percentile(samples.map { Double($0.cpuNS)/1e6 },0.5),mbps:Double(bytes)/median/1000)
}
func save<T: Encodable>(_ value: T, _ path: String) throws {
    let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted,.sortedKeys]
    try e.encode(value).write(to: URL(fileURLWithPath:path),options:.atomic)
}
struct RNG: RandomNumberGenerator {
    var state: UInt64 = 20260930
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
}
struct Correctness: Codable {
    let fixture: String; let strategy: String; let status: String; let detail: String
}
struct Probe: Codable, Sendable { let s: String?; let i: Int64?; let u: UInt64?; let d: Double?; let a: [Int]? }
struct RequiredProbe: Codable, Sendable { let required: Int }
struct DynamicProbe: Codable, Sendable { let value: ATProtocolValueContainer }
struct Memory: Codable {
    let fixture: String; let strategy: String; let wallNS: UInt64; let cpuNS: UInt64
    let rssBefore: UInt64; let peakRSS: UInt64
    let liveBytesBefore: UInt64; let liveBytesRetained: UInt64
    let liveBlocksBefore: UInt64; let liveBlocksRetained: UInt64
    let outputBytes: Int
}

@main struct Main {
 static func main() async throws {
    let args = CommandLine.arguments
    func option(_ name: String, _ fallback: String) -> String {
        guard let i = args.firstIndex(of:name), i+1 < args.count else { return fallback }; return args[i+1]
    }
    let mode = option("--mode","run")
    let out = option("--out","Results")
    try FileManager.default.createDirectory(atPath:out,withIntermediateDirectories:true)
    let fixtureDir = option("--fixtures","Fixtures")
    let manifest = try JSONDecoder().decode(Manifest.self,from:Data(contentsOf:URL(fileURLWithPath:fixtureDir+"/manifest.json")))
    let filter = option("--fixture","")
    let selected = manifest.fixtures.filter { filter.isEmpty || $0.id == filter }
    let fixtures = try selected.map { entry in Fixture(entry:entry,data:try Data(contentsOf:URL(fileURLWithPath:fixtureDir+"/"+entry.file))) }
    let strategies = Strategy.available.filter { option("--strategy","").isEmpty || $0.rawValue == option("--strategy","") }
    guard !fixtures.isEmpty, !strategies.isEmpty else { throw BenchError.message("Empty fixture or strategy selection") }
    let iterations = Int(option("--iterations","80"))!
    #if canImport(FoundationEssentials)
    let sameDecoder = ObjectIdentifier(Foundation.JSONDecoder.self) == ObjectIdentifier(FoundationEssentials.JSONDecoder.self)
    progress("ENV Foundation decoder identity equal=\(sameDecoder) type=\(String(reflecting:JSONDecoder.self))")
    #else
    progress("ENV FoundationEssentials not separately importable; type=\(String(reflecting:JSONDecoder.self))")
    #endif
    // Trigger runtime SIMD selection before reporting it.
    let sampleBytes = Array("hello".utf8)
    _ = sampleBytes.withUnsafeBytes { simdutf_validate_utf8($0.baseAddress!.assumingMemoryBound(to:CChar.self),$0.count) }
    if mode != "cold" && mode != "memory" { _ = try simdParseOnly(Data("{}".utf8)) }
    progress("ENV simdutf=\(String(cString:bench_simdutf_backend())) simdjson=\(simdBackend()) OS=\(ProcessInfo.processInfo.operatingSystemVersionString)")
    #if canImport(ZippyJSON)
    progress("ENV zippyCompat=\(String(cString:bench_zippy_backend()))")
    #endif
    switch mode {
    case "correctness":
        let checks = try validateCorpus(fixtures); try save(checks,out+"/corpus-validation.json")
        var rows: [Correctness] = []
        for f in fixtures {
            let baseline: Data
            do { baseline = try canonical(decode(f,Context(.foundationFresh))) }
            catch { rows.append(.init(fixture:f.entry.id,strategy:"foundationFresh",status:"BASELINE_FAIL",detail:String(describing:error))); continue }
            for s in strategies {
                do {
                    let value = try canonical(decode(f,Context(s)))
                    rows.append(.init(fixture:f.entry.id,strategy:s.rawValue,status:value == baseline ? "equal" : "DIFFERENT",detail:"canonical Petrel re-encoding, \(value.count) bytes"))
                } catch { rows.append(.init(fixture:f.entry.id,strategy:s.rawValue,status:"ERROR",detail:String(describing:error))) }
            }
        }
        try save(rows,out+"/correctness.json")
        var coverage: [String:String] = [:]
        for f in fixtures where f.entry.modelKind == "timeline" {
            let c = try directRecordCoverage(f.data); coverage[f.entry.id] = "\(c.eligible) / \(c.total) top-level post records eligible"
        }
        try save(coverage,out+"/direct-coverage.json")
        try malformed(strategies,out,corpus:fixtures)
        for r in rows { progress("\(r.fixture) \(r.strategy) \(r.status) \(r.detail)") }
    case "structure":
        var rows: [Correctness] = []
        for f in fixtures {
            for s in strategies {
                do {
                    let checks = try validateCorpus([f],strategy:s)
                    rows.append(.init(fixture:f.entry.id,strategy:s.rawValue,status:"passed",detail:checks.joined(separator:"; ")))
                } catch {
                    rows.append(.init(fixture:f.entry.id,strategy:s.rawValue,status:"ERROR",detail:String(describing:error)))
                }
            }
        }
        try save(rows,out+"/structure-correctness.json")
        guard rows.allSatisfy({ $0.status == "passed" }) else { throw BenchError.message("Candidate typed structure mismatch") }
        progress("Typed structure checks passed: \(rows.count) fixture/strategy cells")
    case "canonical":
        // Persist semantic output outside measurements for differential checks across binaries.
        // --no-validate writes outputs even when corpus expectations fail (used to diff a
        // library whose typed/unknown classification legitimately differs on a fixture).
        if !args.contains("--no-validate") {
            let checks = try validateCorpus(fixtures); try save(checks,out+"/corpus-validation.json")
        }
        for f in fixtures {
            for s in strategies {
                let encoded = try canonical(decode(f,Context(s)))
                try encoded.write(to:URL(fileURLWithPath:out+"/\(f.entry.id)-\(s.rawValue).json"),options:.atomic)
            }
        }
    case "cold", "memory":
        let f = fixtures[0]; let s = strategies[0]; let c = Context(s)
        let r0 = bench_peak_rss(), b0 = bench_live_bytes(), n0 = bench_live_blocks()
        let cpu0 = bench_cpu_ns(), t0 = DispatchTime.now().uptimeNanoseconds
        let value = try decode(f,c)
        let t1 = DispatchTime.now().uptimeNanoseconds, cpu1 = bench_cpu_ns()
        let b1 = bench_live_bytes(), n1 = bench_live_blocks(), r1 = bench_peak_rss()
        let encoded = try canonical(value)
        withExtendedLifetime(value) {}
        let row = Memory(fixture:f.entry.id,strategy:s.rawValue,wallNS:t1-t0,cpuNS:cpu1-cpu0,rssBefore:r0,peakRSS:r1,liveBytesBefore:b0,liveBytesRetained:b1,liveBlocksBefore:n0,liveBlocksRetained:n1,outputBytes:encoded.count)
        try save(row,out+"/\(mode)-\(f.entry.id)-\(s.rawValue).json")
        progress("\(mode) \(f.entry.id) \(s.rawValue) \(Double(t1-t0)/1e6) ms; RSS \(r1)")
    case "profile":
        let f = fixtures[0], c = Context(strategies[0])
        let seconds = Double(option("--seconds","30"))!
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(seconds*1e9)
        var count = 0, size = 0
        while DispatchTime.now().uptimeNanoseconds < deadline {
            let result = try decode(f,c)
            withExtendedLifetime(result) { count += 1 }
            if count == 1 { size = try canonical(result).count }
        }
        progress("PROFILE operations=\(count) outputBytes=\(size)")
    case "concurrency":
        var all: [ConcurrentRow] = []
        for f in fixtures {
          for s in strategies where s != .foundationEssentials {
            do {
                guard try canonical(decode(f,Context(s))) == canonical(decode(f,Context(.foundationFresh))) else { progress("SKIP incorrect concurrent \(f.entry.id) \(s)"); continue }
            } catch { progress("SKIP concurrent \(f.entry.id) \(s): \(error)"); continue }
            for workers in [1,2,4,8] where option("--workers","").isEmpty || workers == Int(option("--workers", "0")) {
              let c = Context(s); for _ in 0..<3 { _ = try decode(f,c) }
              let start = DispatchTime.now().uptimeNanoseconds, cpu0 = bench_cpu_ns()
              let samples = try await withThrowingTaskGroup(of:[Sample].self) { group in
                for worker in 0..<workers {
                  group.addTask {
                    let local = Context(s); var times: [Sample] = []
                    times.reserveCapacity(iterations)
                    for i in 0..<iterations {
                      let t0 = DispatchTime.now().uptimeNanoseconds
                      let model = try decode(f,local)
                      let t1 = DispatchTime.now().uptimeNanoseconds
                      withExtendedLifetime(model) {}
                      times.append(Sample(fixture:f.entry.id,strategy:s.rawValue,iteration:worker*iterations+i,wallNS:t1-t0,cpuNS:0))
                    }
                    return times
                  }
                }
                var results: [Sample] = []; for try await batch in group { results += batch }; return results
              }
              let duration = DispatchTime.now().uptimeNanoseconds-start, cpu = bench_cpu_ns()-cpu0
              let sum = summary(samples,bytes:f.data.count)
              let row = ConcurrentRow(fixture:f.entry.id,strategy:s.rawValue,workers:workers,operations:samples.count,wallMS:Double(duration)/1e6,cpuMS:Double(cpu)/1e6,medianMS:sum.medianMS,p95MS:sum.p95MS,mbps:Double(f.data.count*samples.count)/Double(duration)*1000,peakRSS:bench_peak_rss())
              all.append(row)
              progress("CONC \(f.entry.id) \(s.rawValue) \(workers) workers \(row.mbps) MB/s p95 \(row.p95MS) ms")
              try save(all,out+"/concurrency.json")
            }
          }
        }
    case "encode": try encodeMode(fixtures,iterations,out)
    case "micro": try micro(fixtures,iterations,out)
    case "transport": try transportCopyExperiment(fixtures,iterations,out)
    case "stages": try stageExperiment(fixtures,iterations,out)
    default:
        var samples: [Sample] = [], summaries: [Summary] = [], rng = RNG()
        for f in fixtures {
            let contexts = strategies.map { Context($0) }
            var reference: Data? = nil
            var eligible: [Context] = []
            for c in contexts {
                do {
                    let canonicalValue = try canonical(decode(f,c))
                    if reference == nil { reference = canonicalValue }
                    if canonicalValue != reference { progress("SKIP incorrect \(f.entry.id) \(c.strategy)"); continue }
                    for _ in 0..<5 { _ = try decode(f,c) }
                    eligible.append(c)
                } catch { progress("SKIP \(f.entry.id) \(c.strategy) \(error)") }
            }
            for iteration in 0..<iterations {
                for c in eligible.shuffled(using:&rng) {
                    let cpu0 = bench_cpu_ns(), t0 = DispatchTime.now().uptimeNanoseconds
                    let model = try decode(f,c)
                    let t1 = DispatchTime.now().uptimeNanoseconds, cpu1 = bench_cpu_ns()
                    withExtendedLifetime(model) {}
                    samples.append(Sample(fixture:f.entry.id,strategy:c.strategy.rawValue,iteration:iteration,wallNS:t1-t0,cpuNS:cpu1-cpu0))
                }
            }
            for c in eligible {
                let rows = samples.filter { $0.fixture == f.entry.id && $0.strategy == c.strategy.rawValue }
                let sum = summary(rows,bytes:f.data.count); summaries.append(sum)
                progress("RESULT \(sum.fixture) \(sum.strategy) median \(sum.medianMS) ms p95 \(sum.p95MS) MB/s \(sum.mbps)")
            }
            try save(samples,out+"/samples.json"); try save(summaries,out+"/summary.json")
        }
    }
 }
}
struct ConcurrentRow: Codable {
 let fixture: String; let strategy: String; let workers: Int; let operations: Int
 let wallMS: Double; let cpuMS: Double; let medianMS: Double; let p95MS: Double; let mbps: Double; let peakRSS: UInt64
}
