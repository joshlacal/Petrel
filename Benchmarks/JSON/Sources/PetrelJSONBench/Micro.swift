import Foundation
import Petrel
import SimdUTF
import CBenchMetrics
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// Experimental benchmark-only alternatives to Petrel.Bytes. Both preserve the
// production padded-or-unpadded RFC 4648 policy, including canonical unused bits.
// Neither changes the production generated decoder or Petrel source.
struct FastBytes: Decodable {
    let data: Data
    private enum CodingKeys: String, CodingKey { case bytes = "$bytes" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let text = try c.decode(String.self, forKey: .bytes)
        guard let decoded = strictSIMDBase64(text) else {
            throw DecodingError.dataCorruptedError(forKey: .bytes, in: c,
                debugDescription: "String is not canonical RFC 4648 base64")
        }
        data = decoded
    }
}

struct LeanBytes: Decodable {
    let data: Data
    private enum CodingKeys: String, CodingKey { case bytes = "$bytes" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let text = try c.decode(String.self, forKey: .bytes)
        guard let decoded = strictFoundationBase64(text) else {
            throw DecodingError.dataCorruptedError(forKey: .bytes, in: c,
                debugDescription: "String is not canonical RFC 4648 base64")
        }
        data = decoded
    }
}

private struct Base64Shape {
    let paddingToAppend: Int
    let decodedCount: Int
}

@inline(__always) private func sextet(_ byte: UInt8) -> UInt8? {
    switch byte {
    case 65...90: return byte - 65
    case 97...122: return byte - 97 + 26
    case 48...57: return byte - 48 + 52
    case 43: return 62
    case 47: return 63
    default: return nil
    }
}

// One scalar pass, no UTF8/sextet arrays and no replacement strings. Sharing this
// validator means LeanBytes versus FastBytes isolates the binary decoding step.
private func canonicalBase64Shape(_ bytes: UnsafeBufferPointer<UInt8>) -> Base64Shape? {
    var payloadCount = 0
    var paddingCount = 0
    var lastSextet: UInt8 = 0
    for byte in bytes {
        if byte == 61 {
            paddingCount += 1
            if paddingCount > 2 { return nil }
        } else {
            guard paddingCount == 0, let value = sextet(byte) else { return nil }
            payloadCount += 1
            lastSextet = value
        }
    }
    let canonicalPadding: Int
    switch payloadCount % 4 {
    case 0: canonicalPadding = 0
    case 2:
        guard lastSextet & 15 == 0 else { return nil }
        canonicalPadding = 2
    case 3:
        guard lastSextet & 3 == 0 else { return nil }
        canonicalPadding = 1
    default: return nil
    }
    if paddingCount > 0 {
        guard bytes.count.isMultiple(of: 4), paddingCount == canonicalPadding else { return nil }
    }
    return Base64Shape(paddingToAppend: paddingCount == 0 ? canonicalPadding : 0,
                       decodedCount: payloadCount / 4 * 3 + (payloadCount % 4 == 0 ? 0 : payloadCount % 4 - 1))
}

func strictFoundationBase64(_ text: String) -> Data? {
    var contiguous = text
    guard let shape = contiguous.withUTF8({ canonicalBase64Shape($0) }) else { return nil }
    // Standard Foundation requires canonical padding; the production policy also
    // permits no padding, so append it only when actually needed.
    let normalized = shape.paddingToAppend == 0 ? text : text + String(repeating: "=", count: shape.paddingToAppend)
    guard let result = Data(base64Encoded: normalized), result.count == shape.decodedCount else { return nil }
    return result
}

// Allocate the destination once and give ownership directly to Data. simdutf may
// write up to maximal_binary_length, so allocate that capacity even if padding
// makes the final result shorter. No output Array -> Data copy is introduced.
private func simdBase64Owned(_ bytes: UnsafeBufferPointer<UInt8>, expectedCount: Int?) -> Data? {
    guard !bytes.isEmpty else { return Data() }
    let input = UnsafeRawPointer(bytes.baseAddress!).assumingMemoryBound(to: CChar.self)
    let capacity = max(1, simdutf_maximal_binary_length_from_base64(input, bytes.count))
    guard let output = malloc(capacity) else { return nil }
    let conversion = simdutf_base64_to_binary(input, bytes.count,
        output.assumingMemoryBound(to: CChar.self), SIMDUTF_BASE64_DEFAULT, SIMDUTF_LAST_CHUNK_LOOSE)
    guard conversion.error == SIMDUTF_ERROR_SUCCESS,
          expectedCount == nil || conversion.count == expectedCount else {
        free(output)
        return nil
    }
    return Data(bytesNoCopy: output, count: conversion.count, deallocator: .free)
}

func strictSIMDBase64(_ text: String) -> Data? {
    var contiguous = text
    return contiguous.withUTF8 { bytes in
        guard let shape = canonicalBase64Shape(bytes) else { return nil }
        return simdBase64Owned(bytes, expectedCount: shape.decodedCount)
    }
}

private func rawSIMDBase64(_ text: String) -> Data? {
    var contiguous = text
    return contiguous.withUTF8 { simdBase64Owned($0, expectedCount: nil) }
}

private enum MicroValue {
    case object(Any)
    case string(String?)
    case bytes(Data?)
    case flag(Bool)
    case token(Int)
}
private struct MicroCase {
    let name: String
    let operation: () throws -> MicroValue
}
private struct MicroBatch: Codable {
    let fixture: String
    let strategy: String
    let batchSize: Int
    let sampleCount: Int
    let bytesPerOperation: Int
}
private struct MicroMethodology: Codable {
    let notes: [String]
    let batches: [MicroBatch]
    let consumedToken: Int
}

@inline(never) private func microConsume(_ value: MicroValue) -> Int {
    switch value {
    case .object(let object): return withExtendedLifetime(object) { 1 }
    case .string(let text): return text?.utf8.count ?? -1
    case .bytes(let data): return data?.count ?? -1
    case .flag(let valid): return valid ? 1 : -1
    case .token(let token): return token
    }
}

@inline(never) private func microBatch(_ test: MicroCase, count: Int) throws -> Int {
    var sink = 0
    for _ in 0..<count {
        let result = try test.operation()
        sink &+= microConsume(result)
    }
    return sink
}

private func microMeasure(id: String, bytes: Int, tests: [MicroCase], iterations: Int,
    samples: inout [Sample], summaries: inout [Summary], batches: inout [MicroBatch],
    rng: inout RNG, sink: inout Int) throws {
    let count = max(50, iterations)
    var batchSizes: [Int] = []
    for test in tests {
        sink &+= try microBatch(test, count: 5)
        let t0 = DispatchTime.now().uptimeNanoseconds
        sink &+= try microBatch(test, count: 1)
        let ns = max(UInt64(1), DispatchTime.now().uptimeNanoseconds - t0)
        let batch = max(1, min(4096, Int(1_000_000 / ns)))
        batchSizes.append(batch)
        batches.append(MicroBatch(fixture: id, strategy: test.name, batchSize: batch,
                                  sampleCount: count, bytesPerOperation: bytes))
    }
    var local: [Sample] = []
    local.reserveCapacity(count * tests.count)
    for iteration in 0..<count {
        for index in tests.indices.shuffled(using: &rng) {
            let batch = batchSizes[index]
            let c0 = bench_cpu_ns(), t0 = DispatchTime.now().uptimeNanoseconds
            let token = try microBatch(tests[index], count: batch)
            let t1 = DispatchTime.now().uptimeNanoseconds, c1 = bench_cpu_ns()
            sink &+= token
            local.append(Sample(fixture: id, strategy: tests[index].name, iteration: iteration,
                wallNS: (t1 - t0) / UInt64(batch), cpuNS: (c1 - c0) / UInt64(batch)))
        }
    }
    for test in tests {
        let rows = local.filter { $0.strategy == test.name }
        let result = summary(rows, bytes: bytes)
        summaries.append(result)
        print("MICRO \(id) \(test.name) median \(result.medianMS) ms p95 \(result.p95MS) MB/s \(result.mbps)")
    }
    samples += local
}

private func base64JSON(_ text: String) throws -> Data {
    // Setup only; JSONEncoder avoids accidental escape bugs in malformed cases.
    try JSONEncoder().encode(["$bytes": text])
}

private func microCorrectness() throws -> [Correctness] {
    var rows: [Correctness] = []
    let valid = ["", "Zg==", "Zg", "Zm8=", "Zm8", "Zm9v", "+/8=", "+/8", "AA==", "AAA=", "AAAA"]
    let invalid = ["Z", "Zg=", "Zg===", "Zg=A", "====", "Zh==", "Zh", "Zm9=", "Zm9", "Z=g=", "Zg*=", "Zg ==", " Zg==", "Zg==\n", "Zg==\t", "-_8=", "é", "Zg\u{0000}==", "A===", "AA===", "AAA=="]
    for (index, text) in (valid + invalid).enumerated() {
        let json = try base64JSON(text)
        let baseline = try? JSONDecoder().decode(Bytes.self, from: json).data
        let expectedValid = index < valid.count
        rows.append(Correctness(fixture: "base64-policy-\(index)", strategy: "petrelBytes",
            status: (baseline != nil) == expectedValid ? "expected" : "DIFFERENT",
            detail: "input=\(String(reflecting: text)); expected \(expectedValid ? "accept" : "reject"); actual \(baseline != nil ? "accept" : "reject")"))
        let candidates: [(String, Data?)] = [
            ("leanBytes", try? JSONDecoder().decode(LeanBytes.self, from: json).data),
            ("fastBytes", try? JSONDecoder().decode(FastBytes.self, from: json).data)
        ]
        for (name, result) in candidates {
            rows.append(Correctness(fixture: "base64-policy-\(index)", strategy: name,
                status: baseline == result ? "equal" : "DIFFERENT",
                detail: "input=\(String(reflecting: text)); baseline \(baseline != nil ? "accept" : "reject"); candidate \(result != nil ? "accept" : "reject")"))
        }
    }
    // Exercise every possible final sextet so an implementation cannot pass the
    // examples while admitting nonzero discarded bits elsewhere in the alphabet.
    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)
    for (i, byte) in alphabet.enumerated() {
        for (prefix, suffix, mask) in [("A", "==", 15), ("AA", "=", 3)] {
            for padded in [true, false] {
                let text = prefix + String(UnicodeScalar(byte)) + (padded ? suffix : "")
                let json = try base64JSON(text)
                let baseline = try? JSONDecoder().decode(Bytes.self, from: json).data
                let lean = try? JSONDecoder().decode(LeanBytes.self, from: json).data
                let fast = try? JSONDecoder().decode(FastBytes.self, from: json).data
                rows.append(Correctness(fixture: "base64-padbits-\(prefix.count)-\(i)-\(padded)", strategy: "leanBytes+fastBytes",
                    status: baseline == lean && baseline == fast && (baseline != nil) == (i & mask == 0) ? "equal" : "DIFFERENT",
                    detail: "All final sextets; padded/unpadded; input=\(text)"))
            }
        }
    }
    // Invalid UTF-8: lone continuation, overlong encoding, truncated sequence,
    // surrogate, out-of-range scalar, and embedded NUL (which is valid UTF-8).
    let utf8Cases: [(String, [UInt8])] = [
        ("empty", []), ("ascii", [65, 66]), ("nul", [65, 0, 66]),
        ("emoji", [0xF0, 0x9F, 0x90, 0xB8]), ("continuation", [0x80]),
        ("overlong", [0xC0, 0xAF]), ("truncated", [0xE2, 0x82]),
        ("surrogate", [0xED, 0xA0, 0x80]), ("out-of-range", [0xF4, 0x90, 0x80, 0x80])
    ]
    for (name, bytes) in utf8Cases {
        let baseline = String(data: Data(bytes), encoding: .utf8)
        let candidate = bytes.withUnsafeBufferPointer { String(validatingUTF8: $0) }
        let valid = bytes.withUnsafeBytes { raw in
            simdutf_validate_utf8(raw.baseAddress?.assumingMemoryBound(to: CChar.self), raw.count)
        }
        rows.append(Correctness(fixture: "utf8-\(name)", strategy: "simdutf",
            status: candidate == baseline && valid == (baseline != nil) ? "equal" : "DIFFERENT",
            detail: "Foundation validating construction versus SIMD validation and owned construction"))
    }
    return rows
}

func micro(_ fixtures: [Fixture], _ iterations: Int, _ out: String) throws {
    var samples: [Sample] = [], summaries: [Summary] = [], batches: [MicroBatch] = []
    var rng = RNG(), sink = 0
    let correctness = try microCorrectness()
    try save(correctness, out + "/micro-correctness.json")
    guard correctness.allSatisfy({ $0.status == "equal" || $0.status == "expected" }) else {
        throw BenchError.message("Base64/UTF-8 differential failure; see micro-correctness.json")
    }

    for fixture in fixtures {
        let data = fixture.data
        var tests: [MicroCase] = [
            .init(name: "jsonSerialization.parseAndObjectGraph", operation: {
                .object(try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]))
            }),
            .init(name: "simdjson.parseOnly", operation: {
                _ = try simdParseOnly(data)
                return .token(1)
            }),
            .init(name: "utf8.foundationValidateAndConstructString", operation: {
                .string(String(data: data, encoding: .utf8))
            }),
            .init(name: "utf8.simdValidateOnly", operation: {
                .flag(data.withUnsafeBytes { raw in
                    simdutf_validate_utf8(raw.baseAddress?.assumingMemoryBound(to: CChar.self), raw.count)
                })
            }),
            .init(name: "utf8.simdValidateAndConstructString", operation: {
                .string(data.withUnsafeBytes { raw in String(validatingUTF8: raw.bindMemory(to: UInt8.self)) })
            }),
            .init(name: "conversion.foundationDataStringData", operation: {
                .bytes(String(data: data, encoding: .utf8).map { Data($0.utf8) })
            })
        ]
        #if canImport(ZippyJSON)
        tests.append(.init(name: "zippyCompat.parseOnly", operation: {
            let error = data.withUnsafeBytes { bench_zippy_parse($0.baseAddress?.assumingMemoryBound(to:CChar.self),$0.count) }
            if error != 0 { throw BenchError.message("Zippy parse failed \(error)") }
            return .flag(true)
        }))
        #endif
        try microMeasure(id: fixture.entry.id, bytes: data.count, tests: tests, iterations: iterations,
            samples: &samples, summaries: &summaries, batches: &batches, rng: &rng, sink: &sink)
        try save(samples, out + "/micro-samples.json")
        try save(summaries, out + "/micro-summary.json")
    }

    // Load the same sanitized component fixture as the corpus generator outside
    // all timing regions. Smaller/larger buffers are deterministic truncations or
    // repetitions of this payload, not unrelated low-entropy zero-filled input.
    let args = CommandLine.arguments
    let fixturePath: String
    if let i = args.firstIndex(of: "--fixtures"), i + 1 < args.count {
        fixturePath = args[i + 1]
    } else { fixturePath = "Fixtures" }
    let componentText = try String(contentsOfFile: fixturePath + "/base64-payload.txt", encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let seed = Data(base64Encoded: componentText), !seed.isEmpty else {
        throw BenchError.message("Missing or invalid base64-payload.txt fixture")
    }
    for size in [32, 1024, 32768, 1048576] {
        var bytes = Data(capacity: size)
        while bytes.count < size { bytes.append(seed.prefix(min(seed.count, size - bytes.count))) }
        let text = bytes.base64EncodedString()
        let unpadded = text.replacingOccurrences(of: "=", with: "")
        let json = try base64JSON(text), unpaddedJSON = try base64JSON(unpadded)
        // Strong content equality before any timing. Raw kernels are compared on
        // canonical padded data only; their malformed-input policies differ.
        guard Data(base64Encoded: text) == bytes, rawSIMDBase64(text) == bytes,
              strictFoundationBase64(text) == bytes, strictSIMDBase64(text) == bytes,
              strictFoundationBase64(unpadded) == bytes, strictSIMDBase64(unpadded) == bytes,
              try JSONDecoder().decode(Bytes.self, from: json).data == bytes,
              try JSONDecoder().decode(LeanBytes.self, from: json).data == bytes,
              try JSONDecoder().decode(FastBytes.self, from: json).data == bytes,
              try JSONDecoder().decode(Bytes.self, from: unpaddedJSON).data == bytes,
              try JSONDecoder().decode(LeanBytes.self, from: unpaddedJSON).data == bytes,
              try JSONDecoder().decode(FastBytes.self, from: unpaddedJSON).data == bytes else {
            throw BenchError.message("Base64 content mismatch for payload \(size)")
        }
        let kernels: [MicroCase] = [
            .init(name: "base64.foundationRaw", operation: { .bytes(Data(base64Encoded: text)) }),
            .init(name: "base64.simdutfRawOwnedData", operation: { .bytes(rawSIMDBase64(text)) }),
            .init(name: "base64.leanStrictFoundation", operation: { .bytes(strictFoundationBase64(text)) }),
            .init(name: "base64.fastStrictSIMD", operation: { .bytes(strictSIMDBase64(text)) })
        ]
        try microMeasure(id: "base64-kernel-\(size)", bytes: text.utf8.count, tests: kernels, iterations: iterations,
            samples: &samples, summaries: &summaries, batches: &batches, rng: &rng, sink: &sink)
        for (variant, input) in [("padded", json), ("unpadded", unpaddedJSON)] {
            let complete: [MicroCase] = [
                .init(name: "jsonBytes.petrelBytes", operation: { .bytes(try JSONDecoder().decode(Bytes.self, from: input).data) }),
                .init(name: "jsonBytes.leanBytes", operation: { .bytes(try JSONDecoder().decode(LeanBytes.self, from: input).data) }),
                .init(name: "jsonBytes.fastBytes", operation: { .bytes(try JSONDecoder().decode(FastBytes.self, from: input).data) })
            ]
            try microMeasure(id: "base64-json-\(size)-\(variant)", bytes: input.count, tests: complete, iterations: iterations,
                samples: &samples, summaries: &summaries, batches: &batches, rng: &rng, sink: &sink)
        }
        try save(samples, out + "/micro-samples.json")
        try save(summaries, out + "/micro-summary.json")
    }
    let notes = [
        "Optimized executable required. All fixture loading, JSON setup, payload expansion, correctness checks, warmup and batch calibration are outside timing.",
        "At least 50 samples per cell; 5 warmups; strategy order shuffled with fixed seed per sample. Each sample is a batch mean normalized per operation. p95 is a distribution of batch means, not individual call-tail latency. Batch size targets about 1 ms, bounded to 1...4096.",
        "CPU and wall timing wrap each batch. Timed operations include result consumption/release; infrastructure cost is amortized. The accumulated consumed token is exported to prevent dead-code elimination.",
        "jsonSerialization.parseAndObjectGraph is a distinct parser plus Any/Foundation object graph and destruction, not Foundation JSONDecoder syntax-only time. Do not subtract it from model decode time to infer Codable percentage.",
        "simdjson.parseOnly measures the wrapper's actual parse-only operation including any required padded input/DOM setup. It does not construct Petrel models.",
        "Foundation UTF-8 comparison validates and constructs String; simdValidateOnly only validates. Only the two validate-and-construct cells have matching output scope. Conversion cells are hypothetical costs, absent from ordinary Release XRPC.",
        "Base64 raw kernels have different malformed-input policies and use canonical padded valid input. Production-comparable strict candidates share scalar alphabet/padding/pad-bit checks; SIMD writes directly into owned Data. LeanBytes changes both allocation behavior and Character-based sextet classification; it does not isolate allocation cleanup alone.",
        "jsonBytes.* is complete JSON bytes to the actual Petrel.Bytes value or an equivalent benchmark-only wrapper. This is not a full feed/repo response measurement. Fresh JSONDecoder per operation matches generated endpoint lifetime.",
        "Base64 throughput denominator is encoded input bytes including JSON framing where applicable, not decoded output size. Fixture ids state decoded binary bytes. No production Base64/UTF-8 integration is implied.",
        "Differential checks cover valid padded/unpadded data, malformed padding/alphabet/whitespace/url alphabet, every possible final sextet for one/two output bytes, and representative malformed UTF-8. Whole component payload content equality is checked at all four sizes."
    ]
    try save(MicroMethodology(notes: notes, batches: batches, consumedToken: sink), out + "/micro-methodology.json")
    print("MICRO correctness rows=\(correctness.count), consumed token=\(sink)")
}
