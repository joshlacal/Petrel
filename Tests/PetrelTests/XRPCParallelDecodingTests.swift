import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@_spi(XRPCDecodeExperimental) @testable import Petrel
import Synchronization
import Testing

// MARK: - Fixtures

private enum ParallelFixtures {
    static let cid = "bafyreifqkz7gikummmwlitlxwfqnverjhacyeu4i3dytnmhn5bmuowkzoy"

    /// One `app.bsky.feed.defs#feedViewPost` element. Variants cover typed and unknown records,
    /// non-ASCII text, escapes, brackets inside strings, unknown embeds and reasons.
    static func element(_ index: Int) -> String {
        let did = "did:plc:actor\(index % 7)aaaaaaaaaaaaaaaa"
        let text: String = switch index % 5 {
        case 0: #"Plain text \#(index) with \"quotes\", [brackets] and {braces}"#
        case 1: "Unicode \(index): 東京 🦋 é\\u00e9 \\ud83d\\ude00"
        case 2: #"Escaped \\ backslash \/ slash \n newline \#(index)"#
        case 3: "Long " + String(repeating: "lorem ipsum ", count: 20) + "\(index)"
        default: "Short \(index)"
        }
        let record = index % 9 == 4
            ? #"{"$type":"example.future.post","text":"unknown \#(index)","items":[1,null,true,{"x":"]"}]}"#
            : #"{"$type":"app.bsky.feed.post","text":"\#(text)","createdAt":"2026-09-01T00:00:00.000Z","langs":["en"]}"#
        let embed = index % 6 == 3
            ? #","embed":{"$type":"test.example.futureEmbed#view","items":[{"a":1},{"b":[2,3]}]}"#
            : ""
        let reason = index % 8 == 5
            ? #","reason":{"$type":"app.bsky.feed.defs#reasonRepost","by":{"did":"\#(did)","handle":"repost\#(index).example.test"},"indexedAt":"2026-09-01T00:00:00.000Z"}"#
            : ""
        return #"{"post":{"uri":"at://\#(did)/app.bsky.feed.post/bench\#(index)","cid":"\#(cid)","author":{"did":"\#(did)","handle":"actor\#(index).example.test","displayName":"Actor \#(index)"},"record":\#(record)\#(embed),"indexedAt":"2026-09-02T01:01:07.123Z","likeCount":\#(index),"labels":[]}\#(reason)}"#
    }

    static func timeline(count: Int, separator: String = ",", cursor: String = #""cursor":"2026-09-01T00:00:00.000Z::100","#) -> String {
        "{\(cursor)\"feed\":[" + (0 ..< count).map(element).joined(separator: separator) + "]}"
    }

    static func data(_ text: String) -> Data { Data(text.utf8) }
}

private func canonical(_ value: some Encodable) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
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

private func decodeTimeline(_ data: Data, _ configuration: XRPCResponseDecoding.Configuration) async throws -> AppBskyFeedGetTimeline.Output {
    try await XRPCResponseDecoding.$configurationOverride.withValue(configuration) {
        try await XRPCResponseDecoding.decode(AppBskyFeedGetTimeline.Output.self, from: data, endpoint: "test")
    }
}

/// Outcome of a decode as comparable data: canonical bytes, or a structural signature of the error
/// (DecodingError case, coding path, debug description, and the underlying error's type, domain,
/// code and user info with keys sorted). The signature avoids `String(reflecting:)` on the whole
/// error because an underlying NSError prints its user-info dictionary in hash order, which differs
/// between two otherwise identical decodes unless SWIFT_DETERMINISTIC_HASHING is set.
private enum Outcome: Equatable {
    case accepted(Data)
    case rejected(String)
}

private func errorSignature(_ error: Error) -> String {
    func path(_ codingPath: [CodingKey]) -> String {
        codingPath.map { key in key.intValue.map { "[\($0)]" } ?? key.stringValue }.joined(separator: ".")
    }
    func underlying(_ error: Error?) -> String {
        guard let error else { return "-" }
        if error is DecodingError { return errorSignature(error) }
        let ns = error as NSError
        let info = ns.userInfo.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ",")
        return "\(type(of: error))|\(ns.domain)|\(ns.code)|\(info)"
    }
    func context(_ c: DecodingError.Context) -> String {
        "\(path(c.codingPath))|\(c.debugDescription)|\(underlying(c.underlyingError))"
    }
    switch error {
    case let DecodingError.dataCorrupted(c): return "dataCorrupted|" + context(c)
    case let DecodingError.keyNotFound(key, c): return "keyNotFound|\(key.stringValue)|" + context(c)
    case let DecodingError.typeMismatch(type, c): return "typeMismatch|\(type)|" + context(c)
    case let DecodingError.valueNotFound(type, c): return "valueNotFound|\(type)|" + context(c)
    default: return "\(type(of: error))|" + underlying(error)
    }
}

private func outcome(_ body: () async throws -> AppBskyFeedGetTimeline.Output) async -> Outcome {
    do { return try await .accepted(canonical(body())) } catch { return .rejected(errorSignature(error)) }
}

// MARK: - Splitter

@Suite("JSONTopLevelArraySplitter")
struct JSONTopLevelArraySplitterTests {
    private func elements(_ json: String, _ key: String = "feed") -> [String]? {
        let data = Data(json.utf8)
        return JSONTopLevelArraySplitter.split(data, arrayKey: key)?.elements.map {
            String(decoding: data[(data.startIndex + $0.lowerBound) ..< (data.startIndex + $0.upperBound)], as: UTF8.self)
        }
    }

    @Test("Element ranges parse to the same values as the in-document elements")
    func elementRangesMatchJSONSerialization() throws {
        let data = ParallelFixtures.data(ParallelFixtures.timeline(count: 37, separator: " ,\n\t"))
        let layout = try #require(JSONTopLevelArraySplitter.split(data, arrayKey: "feed"))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let feed = try #require(root["feed"] as? [Any])
        #expect(layout.elements.count == feed.count)
        for (index, range) in layout.elements.enumerated() {
            let parsed = try JSONSerialization.jsonObject(with: data[range])
            #expect((parsed as AnyObject).isEqual(feed[index]), "element \(index)")
        }
    }

    @Test("Ranges are relative to a sliced Data's startIndex")
    func slicedData() throws {
        let padded = Data("xxxx".utf8) + Data(#"{"cursor":"c", "feed" : [{"a":1},{"b":2}] }"#.utf8)
        let slice = padded[4...]
        let layout = try #require(JSONTopLevelArraySplitter.split(slice, arrayKey: "feed"))
        func text(_ range: Range<Int>) -> String {
            String(decoding: slice[(slice.startIndex + range.lowerBound) ..< (slice.startIndex + range.upperBound)], as: UTF8.self)
        }
        #expect(layout.elements.map(text) == [#"{"a":1}"#, #"{"b":2}"#])
        #expect(text(layout.array) == #"[{"a":1},{"b":2}]"#)
        let empty = Data(#"{"feed":[ ]}"#.utf8)
        let emptyLayout = try #require(JSONTopLevelArraySplitter.split(empty, arrayKey: "feed"))
        #expect(String(decoding: empty[emptyLayout.array], as: UTF8.self) == "[ ]")
    }

    @Test("Plain shapes are split")
    func plainShapes() {
        #expect(elements(#"{"feed":[]}"#) == [])
        #expect(elements(#" { "cursor" : "a]}\"[{" , "feed" : [ {"x":"]}"} , [1,[2]] , "s\"]" , 12.5e3 , true , null ] } "#)
            == [#"{"x":"]}"}"#, "[1,[2]]", #""s\"]""#, "12.5e3", "true", "null"])
        #expect(elements(#"{"feed":[{"a":"\\"}]}"#) == [#"{"a":"\\"}"#])
        #expect(elements(#"{"other":{"feed":[9]},"feed":[1]}"#) == ["1"], "nested key with the same name is not the target")
        #expect(elements("{\"x\":\"\u{00E9}\u{1F98B}\",\"feed\":[1]}") == ["1"], "non-ASCII string VALUES are fine")
    }

    @Test("Unusual shapes are declined so the sequential decoder decides")
    func declinedShapes() {
        let escapedFeedKey = "\"fe" + "\\" + "u0065d\""
        #expect(elements("{" + escapedFeedKey + ":[1]}") == nil, "escaped key could alias the target")
        #expect(elements(#"{"fe\\ed":[1],"feed":[2]}"#) == nil, "any escaped top-level key declines")
        #expect(elements("{\"k\u{00E9}y\":1,\"feed\":[1]}") == nil, "non-ASCII top-level key declines")
        #expect(elements(#"{"feed":[1],"feed":[2]}"#) == nil, "duplicate target")
        #expect(elements(#"{"feed":null}"#) == nil, "non-array target")
        #expect(elements(#"{"feed":{"a":[1]}}"#) == nil, "object target")
        #expect(elements(#"{"cursor":"x"}"#) == nil, "missing target")
        #expect(elements(#"{}"#) == nil, "empty object")
        #expect(elements(#"{"feed":[1]} x"#) == nil, "trailing bytes")
        #expect(elements(#"[{"feed":[1]}]"#) == nil, "top-level array")
        #expect(elements("\u{FEFF}{\"feed\":[1]}") == nil, "UTF-8 BOM")
        #expect(elements(#"{"feed":[{"a":1}"#) == nil, "unterminated array")
        #expect(elements(#"{"feed":[1,]}"#) == nil, "empty element")
        #expect(elements(#"{"feed":[1 2]}"#) == nil, "missing comma")
        #expect(elements(#"{"feed":[1]"#) == nil, "unterminated object")
        #expect(elements(#"{"feed":["abc]}"#) == nil, "unterminated string")
        #expect(JSONTopLevelArraySplitter.split(Data(#"{"feed":[1]}"#.utf16.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] }), arrayKey: "feed") == nil, "UTF-16")
        let deep = "{\"feed\":[" + String(repeating: "[", count: 500) + String(repeating: "]", count: 500) + "]}"
        #expect(elements(deep) == nil, "element near Foundation's depth limit")
    }

    /// Why non-ASCII keys must decline: Foundation compares decoded keys as Swift Strings, which use
    /// canonical equivalence, so U+212A KELVIN SIGN and "K" are the same key.
    @Test("Canonically equivalent keys alias in JSONDecoder, and the splitter declines them")
    func canonicalEquivalenceAliasing() throws {
        struct KeyedK: Decodable { let K: [Int] }
        let json = "{\"\u{212A}\":[1,2,3]}"
        let decoded = try JSONDecoder().decode(KeyedK.self, from: Data(json.utf8))
        #expect(decoded.K == [1, 2, 3], "Foundation resolved the Kelvin-sign key as \"K\"")
        #expect(elements(json, "K") == nil)
    }
}

// MARK: - Parallel decode equivalence

@Suite("XRPC parallel array decoding")
struct XRPCParallelArrayDecodingTests {
    @Test("Parallel decode equals the sequential decode at every chunk count and worker limit")
    func equivalenceAcrossChunking() async throws {
        let data = ParallelFixtures.data(ParallelFixtures.timeline(count: 45))
        let sequential = try JSONDecoder().decode(AppBskyFeedGetTimeline.Output.self, from: data)
        let reference = try canonical(sequential)
        #expect(sequential.feed.count == 45)
        for workers in [nil, 1, 2, 3, 8] as [Int?] {
            for chunks in [nil, 1, 2, 3, 4, 7, 16, 45, 64] as [Int?] {
                let parallel = try await decodeTimeline(data, forced(chunks: chunks, workers: workers))
                #expect(parallel.cursor == sequential.cursor)
                #expect(parallel.feed == sequential.feed, "chunks=\(String(describing: chunks)) workers=\(String(describing: workers))")
                #expect(try canonical(parallel) == reference)
            }
        }
    }

    @Test("Statistics show which path ran")
    func statisticsPaths() async throws {
        let large = ParallelFixtures.data(ParallelFixtures.timeline(count: 30))
        let small = ParallelFixtures.data(ParallelFixtures.timeline(count: 3))
        // Statistics are process-wide; use deltas and only assert lower bounds so concurrent suites
        // that also decode cannot make this test flaky.
        var before = XRPCResponseDecoding.statistics()
        _ = try await decodeTimeline(large, forced(chunks: 4))
        var after = XRPCResponseDecoding.statistics()
        #expect(after.parallelDecodes >= before.parallelDecodes + 1)

        var thresholds = forced(chunks: 4)
        thresholds.parallelMinimumElements = 8
        before = XRPCResponseDecoding.statistics()
        _ = try await decodeTimeline(small, thresholds)
        after = XRPCResponseDecoding.statistics()
        #expect(after.belowThreshold >= before.belowThreshold + 1)

        before = XRPCResponseDecoding.statistics()
        _ = try? await decodeTimeline(Data("\u{FEFF}".utf8) + large, forced(chunks: 4))
        after = XRPCResponseDecoding.statistics()
        #expect(after.splitterDeclined >= before.splitterDeclined + 1)
    }

    @Test("Parallel decoding is off by default and the default thresholds keep small responses sequential")
    func defaults() {
        let standard = XRPCResponseDecoding.Configuration.standard
        #expect(standard.parallelArrayDecoding == false)
        #expect(standard.checksCancellationBeforeDecode == true)
        #expect(standard.parallelMinimumBytes == 64 * 1024)
        #expect(standard.parallelMinimumElements == 8)
        let plan = XRPCParallelArrayDecoder.WorkPlan(elementCount: 100, configuration: XRPCResponseDecoding.Configuration(parallelMaximumWorkers: 6))
        #expect(plan.workerCount == 6)
        #expect(plan.chunkCount == 24, "more chunks than workers so faster cores claim more work")
        let tiny = XRPCParallelArrayDecoder.WorkPlan(elementCount: 3, configuration: XRPCResponseDecoding.Configuration(parallelMaximumWorkers: 6))
        #expect(tiny.chunkCount == 3 && tiny.workerCount == 3)
    }

    @Test("Malformed and unusual documents give the sequential decoder's exact outcome")
    func malformedOutcomes() async throws {
        let base = ParallelFixtures.timeline(count: 12)
        func replacingFirst(_ text: String, _ target: String, _ replacement: String) -> String {
            guard let range = text.range(of: target) else { return text }
            return text.replacingCharacters(in: range, with: replacement)
        }
        var variants: [(String, Data)] = [
            ("unchanged", base),
            ("truncated", String(base.dropLast(7))),
            ("trailing garbage", base + " ]"),
            ("double comma", replacingFirst(base, "}},{", "}},,{")),
            ("bracket mismatch", replacingFirst(base, "]}},{", "}}},{")),
            ("element not an object", replacingFirst(base, "\"feed\":[", "\"feed\":[1,")),
            ("element null", replacingFirst(base, "\"feed\":[", "\"feed\":[null,")),
            ("element empty object", replacingFirst(base, "\"feed\":[", "\"feed\":[{},")),
            ("element missing required cid", replacingFirst(base, "\"cid\":\"\(ParallelFixtures.cid)\",", "")),
            ("nested Int overflow (internal JSONError path)", replacingFirst(base, "\"likeCount\":3", "\"likeCount\":9223372036854775808")),
            ("nested non-integral number", replacingFirst(base, "\"likeCount\":3", "\"likeCount\":3.5")),
            ("nested huge number", replacingFirst(base, "\"likeCount\":3", "\"likeCount\":1e400")),
            ("invalid escape", replacingFirst(base, "Short 9", "Short \\q9")),
            ("lone surrogate", replacingFirst(base, "Short 9", "Short \\uD8009")),
            ("raw control character", replacingFirst(base, "Short 9", "Short \u{01}9")),
            ("cursor wrong type degrades to nil", ParallelFixtures.timeline(count: 12, cursor: #""cursor":42,"#)),
            ("feed null", replacingFirst(base, "\"feed\":[", "\"feed\":null,\"x\":[")),
            ("feed missing", replacingFirst(base, "\"feed\":", "\"xfeed\":")),
            ("duplicate feed key", String(base.dropLast()) + ",\"feed\":[]}"),
            ("escaped feed key", replacingFirst(base, "\"feed\":", "\"fe\\u0065d\":")),
            ("deep element (600)", replacingFirst(base, "\"feed\":[", "\"feed\":[{\"d\":" + String(repeating: "[", count: 600) + String(repeating: "]", count: 600) + "},")),
            ("deep element (508)", replacingFirst(base, "\"feed\":[", "\"feed\":[{\"d\":" + String(repeating: "[", count: 508) + String(repeating: "]", count: 508) + "},")),
        ].map { ($0.0, Data($0.1.utf8)) }
        var invalidUTF8 = Array(base.utf8)
        if let index = invalidUTF8.firstIndex(of: UInt8(ascii: "S")) { invalidUTF8[index] = 0xC0 }
        variants.append(("invalid UTF-8 byte inside an element", Data(invalidUTF8)))

        for (name, data) in variants {
            let sequential = await outcome { try JSONDecoder().decode(AppBskyFeedGetTimeline.Output.self, from: data) }
            for chunks in [1, 3, 12] {
                let parallel = await outcome { try await decodeTimeline(data, forced(chunks: chunks)) }
                #expect(parallel == sequential, "\(name), chunks=\(chunks)")
            }
        }
    }

    @Test("Generated outputs: eligible ones conform, others do not")
    func generatedConformances() {
        #expect(AppBskyFeedGetTimeline.Output.parallelArrayKey == "feed")
        #expect(AppBskyFeedGetAuthorFeed.Output.parallelArrayKey == "feed")
        #expect(AppBskyNotificationListNotifications.Output.parallelArrayKey == "notifications")
        #expect(AppBskyFeedGetPosts.Output.parallelArrayKey == "posts")
        #expect(AppBskyActorSearchActors.Output.parallelArrayKey == "actors")
        #expect(ComAtprotoRepoListRecords.Output.parallelArrayKey == "records")
        #expect(AppBskyUnspeccedGetPostThreadV2.Output.parallelArrayKey == "thread")
        #expect(ChatBskyConvoGetMessages.Output.parallelArrayKey == "messages")
        // Single object outputs and outputs without a required array are not eligible.
        #expect(!((AppBskyFeedGetPostThread.Output.self as Any.Type) is any XRPCParallelArrayDecodable.Type))
        #expect(!((AppBskyActorGetProfile.Output.self as Any.Type) is any XRPCParallelArrayDecodable.Type))
        #expect(!((ComAtprotoServerDescribeServer.Output.self as Any.Type) is any XRPCParallelArrayDecodable.Type))
    }

    @Test("Prototype decode (array blanked to []) plus elements reassembles Output.init(from:)'s value")
    func prototypeAssembly() throws {
        for cursor in [#""cursor":"abc","#, #""cursor":42,"#, #""cursor":null,"#, ""] {
            let data = ParallelFixtures.data(ParallelFixtures.timeline(count: 3, cursor: cursor) + " ")
            let layout = try #require(JSONTopLevelArraySplitter.split(data, arrayKey: "feed"))
            let prototype = try XRPCParallelArrayDecoder.decodePrototype(AppBskyFeedGetTimeline.Output.self, from: data, array: layout.array)
            let output = try JSONDecoder().decode(AppBskyFeedGetTimeline.Output.self, from: data)
            #expect(prototype.feed.isEmpty)
            #expect(prototype.cursor == output.cursor)
            let assembled = AppBskyFeedGetTimeline.Output(parallelArrayPrototype: prototype, parallelArrayElements: output.feed)
            #expect(try canonical(assembled) == canonical(output))
        }
        // The whole-document scan runs on the original bytes: a syntax error inside the array fails
        // the prototype step even though the blanked copy would parse.
        let broken = ParallelFixtures.data(#"{"feed":[{"a":tru}]}"#)
        let layout = try #require(JSONTopLevelArraySplitter.split(broken, arrayKey: "feed"))
        #expect(throws: DecodingError.self) {
            try XRPCParallelArrayDecoder.decodePrototype(AppBskyFeedGetTimeline.Output.self, from: broken, array: layout.array)
        }
    }
}

// MARK: - Cancellation

private struct CountingOutput: Decodable, Sendable {
    static let decodes = Atomic<Int>(0)
    init(from decoder: Decoder) throws {
        Self.decodes.wrappingAdd(1, ordering: .relaxed)
        _ = try decoder.singleValueContainer()
    }
}

@Suite("XRPC decode entry cancellation", .serialized)
struct XRPCDecodeCancellationTests {
    private func runCancelled<T: Sendable>(_ body: @escaping @Sendable () async throws -> T) async -> Result<T, Error> {
        await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            do { return try await .success(body()) } catch { return .failure(error) }
        }.value
    }

    @Test("A cancelled task throws CancellationError before decoding (general overload)")
    func generalOverload() async {
        let before = CountingOutput.decodes.load(ordering: .relaxed)
        let result = await runCancelled {
            try await XRPCResponseDecoding.$configurationOverride.withValue(.standard) {
                try await XRPCResponseDecoding.decode(CountingOutput.self, from: Data("{}".utf8), endpoint: "test")
            }
        }
        #expect(throws: CancellationError.self) { try result.get() }
        #expect(CountingOutput.decodes.load(ordering: .relaxed) == before, "no decode ran")
    }

    @Test("A cancelled task throws CancellationError before decoding (parallel overload, parallel on and off)")
    func parallelOverload() async {
        let data = ParallelFixtures.data(ParallelFixtures.timeline(count: 20))
        for configuration in [XRPCResponseDecoding.Configuration.standard, forced(chunks: 4)] {
            let result = await runCancelled { try await decodeTimeline(data, configuration) }
            #expect(throws: CancellationError.self) { try result.get() }
        }
    }

    @Test("With the check switched off, a cancelled task still decodes (previous behaviour)")
    func switchOff() async throws {
        let data = ParallelFixtures.data(ParallelFixtures.timeline(count: 20))
        let sequential = try canonical(JSONDecoder().decode(AppBskyFeedGetTimeline.Output.self, from: data))
        var configurations = [XRPCResponseDecoding.Configuration(checksCancellationBeforeDecode: false)]
        var parallel = forced(chunks: 4)
        parallel.checksCancellationBeforeDecode = false
        configurations.append(parallel)
        for configuration in configurations {
            let result = await runCancelled { try await decodeTimeline(data, configuration) }
            #expect(try canonical(result.get()) == sequential)
        }
        let counted = await runCancelled {
            try await XRPCResponseDecoding.$configurationOverride.withValue(XRPCResponseDecoding.Configuration(checksCancellationBeforeDecode: false)) {
                try await XRPCResponseDecoding.decode(CountingOutput.self, from: Data("{}".utf8), endpoint: "test")
            }
        }
        #expect((try? counted.get()) != nil)
    }

    @Test("decodeSuccessfulResponse: value on success, nil on decode failure, CancellationError when cancelled")
    func successfulResponseWrapper() async throws {
        let data = ParallelFixtures.data(ParallelFixtures.timeline(count: 20))
        let sequential = try canonical(JSONDecoder().decode(AppBskyFeedGetTimeline.Output.self, from: data))
        for configuration in [XRPCResponseDecoding.Configuration.standard, forced(chunks: 4)] {
            let value = try await XRPCResponseDecoding.$configurationOverride.withValue(configuration) {
                try await XRPCResponseDecoding.decodeSuccessfulResponse(AppBskyFeedGetTimeline.Output.self, from: data, endpoint: "test")
            }
            #expect(try canonical(#require(value)) == sequential)
            let failed = try await XRPCResponseDecoding.$configurationOverride.withValue(configuration) {
                try await XRPCResponseDecoding.decodeSuccessfulResponse(AppBskyFeedGetTimeline.Output.self, from: Data(#"{"feed":[{}]}"#.utf8), endpoint: "test")
            }
            #expect(failed == nil)
            let cancelled = await runCancelled {
                try await XRPCResponseDecoding.$configurationOverride.withValue(configuration) {
                    try await XRPCResponseDecoding.decodeSuccessfulResponse(AppBskyFeedGetTimeline.Output.self, from: data, endpoint: "test")
                }
            }
            #expect(throws: CancellationError.self) { try cancelled.get() }
        }
        let generalFailure = try await XRPCResponseDecoding.decodeSuccessfulResponse(CountingOutput.self, from: Data("not json".utf8), endpoint: "test")
        #expect(generalFailure == nil)
    }

    @Test("A live task decodes normally through both overloads")
    func notCancelled() async throws {
        let data = ParallelFixtures.data(ParallelFixtures.timeline(count: 20))
        let sequential = try canonical(JSONDecoder().decode(AppBskyFeedGetTimeline.Output.self, from: data))
        #expect(try await canonical(decodeTimeline(data, .standard)) == sequential)
        #expect(try await canonical(decodeTimeline(data, forced(chunks: nil))) == sequential)
    }
}

// MARK: - In-place response accumulation

private final class DeliveredResult: Sendable {
    private let value = Mutex<Result<(Data, URLResponse), Error>?>(nil)
    func store(_ result: Result<(Data, URLResponse), Error>) { value.withLock { $0 = result } }
    func load() -> Result<(Data, URLResponse), Error>? { value.withLock { $0 } }
}

@Suite("TaskContextManager in-place accumulation")
struct TaskContextManagerAccumulationTests {
    private func makeTask() -> URLSessionTask {
        URLSession(configuration: .ephemeral).dataTask(with: URL(string: "https://example.com/xrpc/test")!)
    }

    private func body(_ size: Int) -> Data {
        Data((0 ..< size).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ $0 >> 7) })
    }

    @Test("Chunked bodies are reassembled byte for byte", arguments: [1, 7, 1024, 4096, 16384, 65536])
    func reassembly(chunkSize: Int) async throws {
        let manager = HardenedURLSessionDelegate.TaskContextManager()
        let task = makeTask()
        let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let expected = body(200_000)
        let delivered = DeliveredResult()
        manager.register(task) { result in delivered.store(result) }
        manager.setResponse(response, for: task)
        var offset = 0
        while offset < expected.count {
            let chunk = expected[offset ..< min(expected.count, offset + chunkSize)]
            #expect(manager.receive(Data(chunk), for: task, limit: 10_000_000) == false)
            offset += chunkSize
        }
        #expect(manager.getContext(for: task).wireBytesReceived == expected.count)
        manager.finish(task, error: nil)
        let result = try #require(delivered.load())
        #expect(try result.get().0 == expected)
    }

    @Test("Wire limit: the exceeding chunk is not appended, the task is flagged, finish fails")
    func wireLimit() throws {
        let manager = HardenedURLSessionDelegate.TaskContextManager()
        let task = makeTask()
        let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let delivered = DeliveredResult()
        manager.register(task) { result in delivered.store(result) }
        manager.setResponse(response, for: task)
        #expect(manager.receive(Data(repeating: 1, count: 1000), for: task, limit: 1500) == false)
        #expect(manager.receive(Data(repeating: 2, count: 1000), for: task, limit: 1500) == true)
        let context = manager.getContext(for: task)
        #expect(context.data == Data(repeating: 1, count: 1000), "exceeding chunk not appended")
        #expect(context.wireBytesReceived == 2000)
        #expect(context.limitExceeded)
        #expect(manager.isLimitExceeded(for: task))
        manager.finish(task, error: nil)
        let result = try #require(delivered.load())
        #expect(throws: NetworkError.self) { try result.get() }
        manager.pruneCompletedTask(task)
        #expect(!manager.isLimitExceeded(for: task))
    }

    @Test("receive matches addWireBytes followed by append")
    func receiveMatchesTwoStepShape() {
        let oneStep = HardenedURLSessionDelegate.TaskContextManager()
        let twoStep = HardenedURLSessionDelegate.TaskContextManager()
        let a = makeTask(), b = makeTask()
        let chunks = (0 ..< 40).map { Data(repeating: UInt8($0), count: 37 * ($0 + 1)) }
        for chunk in chunks {
            let exceeded = oneStep.receive(chunk, for: a, limit: 20_000)
            let exceeded2 = twoStep.addWireBytes(chunk.count, for: b, limit: 20_000)
            if !exceeded2 { twoStep.append(chunk, for: b) }
            #expect(exceeded == exceeded2)
        }
        let x = oneStep.getContext(for: a), y = twoStep.getContext(for: b)
        #expect(x.data == y.data)
        #expect(x.wireBytesReceived == y.wireBytesReceived)
        #expect(x.limitExceeded == y.limitExceeded)
        #expect(oneStep.isLimitExceeded(for: a) == twoStep.isLimitExceeded(for: b))
    }

    @Test("Redirect approval resets the body and wire count in place")
    func redirectReset() {
        let manager = HardenedURLSessionDelegate.TaskContextManager()
        let task = makeTask()
        _ = manager.receive(Data(repeating: 9, count: 500), for: task, limit: 10_000)
        manager.approveRedirect(["93.184.216.34"], for: task)
        let context = manager.getContext(for: task)
        #expect(context.data.isEmpty)
        #expect(context.wireBytesReceived == 0)
        #expect(context.approvedAddresses == ["93.184.216.34"])
        #expect(manager.receive(Data(repeating: 1, count: 10), for: task, limit: 10_000) == false)
        #expect(manager.getContext(for: task).data == Data(repeating: 1, count: 10))
    }

    @Test("Security violation always wins at finish")
    func securityViolation() throws {
        let manager = HardenedURLSessionDelegate.TaskContextManager()
        let task = makeTask()
        let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let delivered = DeliveredResult()
        manager.register(task) { result in delivered.store(result) }
        manager.setResponse(response, for: task)
        _ = manager.receive(Data("{}".utf8), for: task, limit: 10_000)
        manager.recordSecurityViolation(for: task)
        #expect(manager.hasAnySecurityViolation())
        manager.finish(task, error: nil)
        let result = try #require(delivered.load())
        do {
            _ = try result.get()
            Issue.record("expected a security violation")
        } catch let error as NetworkError {
            guard case .securityViolation = error else {
                Issue.record("unexpected \(error)")
                return
            }
        }
        #expect(manager.isSecurityViolation(for: task), "violation retained until pruned")
        manager.pruneCompletedTask(task)
        #expect(!manager.isSecurityViolation(for: task))
    }
}
