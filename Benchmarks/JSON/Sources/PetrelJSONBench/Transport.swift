import Foundation

// Reproduces the ownership shape of TaskContextManager.updateContext; no networking is timed.
private struct ResponseContext { var data = Data() }
@inline(never) private func accumulated(_ chunks: [Data], inPlace: Bool) -> Data {
    var contexts = [1: ResponseContext()]
    for chunk in chunks {
        if inPlace { contexts[1, default:ResponseContext()].data.append(chunk) }
        else {
            var context = contexts[1] ?? ResponseContext()
            context.data.append(chunk)
            contexts[1] = context
        }
    }
    return contexts[1]!.data
}
func transportCopyExperiment(_ fixtures: [Fixture], _ iterations: Int, _ out: String) throws {
    var summaries: [Summary] = [], samples: [Sample] = []
    for fixture in fixtures where fixture.entry.modelKind == "timeline" {
        for chunkSize in [4096,16384,65536] {
            let chunks = stride(from:0,to:fixture.data.count,by:chunkSize).map { offset in
                fixture.data.subdata(in:offset..<min(offset+chunkSize,fixture.data.count))
            }
            for inPlace in [false,true] {
                let name = (inPlace ? "dictionary_inplace" : "dictionary_copy_update")+"_\(chunkSize)"
                guard accumulated(chunks,inPlace:inPlace) == fixture.data else { throw BenchError.message("Transport bytes differ") }
                for _ in 0..<5 { _ = accumulated(chunks,inPlace:inPlace) }
                var rows: [Sample] = []
                for i in 0..<iterations {
                    let t0 = DispatchTime.now().uptimeNanoseconds
                    let result = accumulated(chunks,inPlace:inPlace)
                    let t1 = DispatchTime.now().uptimeNanoseconds
                    withExtendedLifetime(result) {}
                    rows.append(Sample(fixture:fixture.entry.id,strategy:name,iteration:i,wallNS:t1-t0,cpuNS:0))
                }
                summaries.append(summary(rows,bytes:fixture.data.count)); samples += rows
            }
        }
    }
    try save(summaries,out+"/transport-summary.json"); try save(samples,out+"/transport-samples.json")
}
