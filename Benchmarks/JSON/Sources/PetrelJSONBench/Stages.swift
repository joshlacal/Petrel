import Foundation
import Petrel
import CBenchMetrics

@inline(never) private func construct(_ f: Fixture, _ document: SIMDDocument) throws -> Model {
    let d = DOMDecoder(node:document.root)
    switch f.entry.modelKind {
    case "profile": return try d.decode(AppBskyActorGetProfile.Output.self)
    case "search": return try d.decode(AppBskyActorSearchActors.Output.self)
    case "timeline": return try d.decode(AppBskyFeedGetTimeline.Output.self)
    case "records": return try d.decode(ComAtprotoRepoListRecords.Output.self)
    default: throw BenchError.message("Unknown fixture")
    }
}
func stageExperiment(_ fixtures:[Fixture],_ iterations:Int,_ out:String) throws {
    var samples:[Sample]=[], sums:[Summary]=[]
    for f in fixtures {
        let parsed = try SIMDDocument(f.data)
        guard try canonical(construct(f,parsed)) == canonical(decode(f,Context(.foundationFresh))) else { throw BenchError.message("Preparsed model mismatch") }
        for _ in 0..<5 { _ = try construct(f,parsed) }
        var rows:[Sample]=[]
        for i in 0..<iterations {
            let c0=bench_cpu_ns(), t0=DispatchTime.now().uptimeNanoseconds
            let model = try construct(f,parsed)
            let t1=DispatchTime.now().uptimeNanoseconds, c1=bench_cpu_ns()
            withExtendedLifetime(model) {}
            rows.append(Sample(fixture:f.entry.id,strategy:"simdPreparsedModel",iteration:i,wallNS:t1-t0,cpuNS:c1-c0))
        }
        samples += rows; sums.append(summary(rows,bytes:f.data.count)); withExtendedLifetime(parsed) {}
        progress("STAGE \(f.entry.id) \(sums.last!.medianMS) ms")
        try save(samples,out+"/stage-samples.json"); try save(sums,out+"/stage-summary.json")
    }
}
