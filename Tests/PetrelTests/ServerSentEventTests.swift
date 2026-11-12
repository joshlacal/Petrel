import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Testing

/// The `text/event-stream` reader behind generated event-stream queries (re-audit r-6).
@Suite("Server-sent events")
struct ServerSentEventTests {
    private static func parse(_ chunks: [[UInt8]]) throws -> [ServerSentEvent] {
        var parser = ServerSentEventParser()
        return try chunks.flatMap { try parser.consume($0) }
    }

    private static func parse(_ text: String) throws -> [ServerSentEvent] {
        try parse([Array(text.utf8)])
    }

    @Test("Data lines join with newlines, and an event ends at a blank line")
    func dataLinesAndDispatch() throws {
        let events = try Self.parse("data: {\"a\":1}\n\nevent: tick\ndata:first\ndata: second\nid: 7\n\n")

        #expect(events == [
            ServerSentEvent(type: "message", data: "{\"a\":1}", lastEventID: ""),
            ServerSentEvent(type: "tick", data: "first\nsecond", lastEventID: "7"),
        ])
    }

    @Test("CR, LF and CRLF all end a line, also when CR and LF arrive in different chunks")
    func lineEndings() throws {
        let events = try Self.parse([
            Array("data: a\r\n\r\ndata: b\r\r".utf8),
            Array("data: c\r".utf8),
            Array("\n\r".utf8),
            Array("\n".utf8),
        ])

        #expect(events.map(\.data) == ["a", "b", "c"])
    }

    @Test("A multi-byte UTF-8 character split across chunks is read whole")
    func splitMultiByteCharacter() throws {
        let bytes = Array("data: caf\u{E9} \u{1F426}\n\n".utf8)
        let split = bytes.firstIndex(of: 0xC3)! + 1
        let events = try Self.parse([Array(bytes[..<split]), Array(bytes[split...])])

        #expect(events.map(\.data) == ["caf\u{E9} \u{1F426}"])
    }

    @Test("Comments, a leading BOM, unknown fields and an unterminated last event produce nothing")
    func ignoredInput() throws {
        let events = try Self.parse([[0xEF, 0xBB, 0xBF] + Array(": keep-alive\n\nretry: 10\nfoo: bar\n\ndata: x\n\ndata: cut".utf8)])

        #expect(events.map(\.data) == ["x"])
    }

    @Test("An event larger than the limit fails the stream")
    func eventTooLarge() throws {
        var parser = ServerSentEventParser(maximumEventBytes: 16)

        #expect(throws: NetworkError.self) {
            _ = try parser.consume(Array("data: 0123456789\ndata: 0123456789\n\n".utf8))
        }
    }

    #if canImport(Darwin) || canImport(Glibc)
        private static func collect(_ request: URLRequest) async throws -> [ServerSentEvent] {
            var events: [ServerSentEvent] = []
            for try await event in ServerSentEventTransport.events(for: request) {
                events.append(event)
            }
            return events
        }

        @Test("The transport streams the events of a text/event-stream response")
        func transportReadsEvents() async throws {
            let server = try PolicyLoopbackHTTPServer { _ in
                .init(
                    headers: ["Content-Type": "text/event-stream; charset=utf-8"],
                    body: Data("data: {\"seq\":1}\n\n: ping\n\ndata: {\"seq\":2}\n\n".utf8)
                )
            }
            defer { server.stop() }

            let events = try await Self.collect(URLRequest(url: server.baseURL.appendingPathComponent("xrpc/x")))

            #expect(events.map(\.data) == [#"{"seq":1}"#, #"{"seq":2}"#])
        }

        @Test("The transport refuses another content type and a non-200 status")
        func transportRejectsWrongResponses() async throws {
            let json = try PolicyLoopbackHTTPServer { _ in
                .init(headers: ["Content-Type": "application/json"], body: Data("data: {}\n\n".utf8))
            }
            defer { json.stop() }
            await #expect(throws: NetworkError.self) {
                _ = try await Self.collect(URLRequest(url: json.baseURL))
            }

            let failing = try PolicyLoopbackHTTPServer { _ in
                .init(statusCode: 500, headers: ["Content-Type": "text/event-stream"], body: Data("data: {}\n\n".utf8))
            }
            defer { failing.stop() }
            await #expect(throws: NetworkError.self) {
                _ = try await Self.collect(URLRequest(url: failing.baseURL))
            }
        }

        @Test("The transport does not follow a redirect")
        func transportRefusesRedirects() async throws {
            let target = try PolicyLoopbackHTTPServer { _ in
                .init(headers: ["Content-Type": "text/event-stream"], body: Data("data: leaked\n\n".utf8))
            }
            defer { target.stop() }
            let source = try PolicyLoopbackHTTPServer { _ in
                .init(statusCode: 302, headers: ["Location": target.baseURL.appendingPathComponent("x").absoluteString])
            }
            defer { source.stop() }

            await #expect(throws: NetworkError.self) {
                _ = try await Self.collect(URLRequest(url: source.baseURL))
            }
            #expect(target.requests.isEmpty)
        }
    #endif
}
