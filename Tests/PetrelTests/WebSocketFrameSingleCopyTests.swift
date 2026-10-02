import Foundation
@testable import Petrel
import Testing

/// DAG-CBOR lane: the frame decoder now copies the frame once and scans/parses the header and
/// payload as slices of that copy. These pin every branch's outcome.
@Suite("WebSocket frame decoder single-copy outcomes")
struct WebSocketFrameSingleCopyTests {
    private static func head(_ major: UInt8, _ argument: Int) -> [UInt8] {
        precondition(argument < 256)
        return argument < 24 ? [major << 5 | UInt8(argument)] : [major << 5 | 24, UInt8(argument)]
    }

    private static func text(_ s: String) -> [UInt8] { head(3, s.utf8.count) + Array(s.utf8) }

    /// Pairs must already be in DAG-CBOR canonical order unless a test wants otherwise.
    private static func map(_ pairs: [(String, [UInt8])]) -> [UInt8] {
        pairs.reduce(head(5, pairs.count)) { $0 + text($1.0) + $1.1 }
    }

    private static let commitHeader = map([("t", text("#commit")), ("op", [0x01])])
    /// The decoder only recognises an error frame whose `op` is the UInt64 bit pattern of -1.
    private static let errorHeader = map([("op", [0x1B] + [UInt8](repeating: 0xFF, count: 8))])
    /// A spec error frame (`op` encoded as CBOR negative -1) does not match `.unsignedInt` and is
    /// reported as a missing/invalid op. Pinned as current behaviour (latent bug, not changed here).
    private static let specErrorHeader = map([("op", [0x20])])

    private static func invalidResponse(_ body: () throws -> Void) -> String? {
        do {
            try body()
            return nil
        } catch let NetworkError.invalidResponse(description) {
            return description
        } catch {
            return "unexpected \(error)"
        }
    }

    @Test("Valid frame decodes with the resolved message type")
    func validFrame() throws {
        let payload = Self.map([("a", [0x01]), ("seq", [0x18, 0x2A])])
        let frame = Data(Self.commitHeader + payload)
        let decoded = try ATProtoWebSocketFrameDecoder.decodeFrame(frame, defaultLexicon: "com.atproto.sync.subscribeRepos")
        #expect(decoded.messageType == "com.atproto.sync.subscribeRepos#commit")
        let json = try JSONSerialization.jsonObject(with: decoded.jsonData) as? [String: Any]
        #expect(json?["a"] as? Int == 1)
        #expect(json?["seq"] as? Int == 42)
        #expect(json?["$type"] as? String == "com.atproto.sync.subscribeRepos#commit")
    }

    @Test("A frame re-based from a larger buffer decodes the same")
    func rebasedFrame() throws {
        let payload = Self.map([("a", [0x01])])
        let big = Data([0xAA, 0xBB] + Self.commitHeader + payload)
        let frame = Data(big[2...])
        #expect(try ATProtoWebSocketFrameDecoder.decodeFrame(frame).messageType == "#commit")
    }

    @Test("Error frame surfaces the server error name")
    func errorFrame() {
        let payload = Self.map([("error", Self.text("FutureCursor")), ("message", Self.text("m"))])
        let frame = Data(Self.errorHeader + payload)
        do {
            _ = try ATProtoWebSocketFrameDecoder.decodeFrame(frame)
            Issue.record("expected an error")
        } catch let NetworkError.serverError(code, message) {
            #expect(code == 400)
            #expect(message == "FutureCursor")
        } catch {
            Issue.record("unexpected \(error)")
        }
    }

    @Test("Spec error frame (op = -1 as a CBOR negative) is reported as an invalid op")
    func specErrorFrame() {
        let payload = Self.map([("error", Self.text("FutureCursor"))])
        let message = Self.invalidResponse { _ = try ATProtoWebSocketFrameDecoder.decodeFrame(Data(Self.specErrorHeader + payload)) }
        #expect(message == "Missing or invalid 'op' in header")
    }

    @Test("Error frame with no payload fails the payload preflight")
    func errorFrameWithoutPayload() {
        let message = Self.invalidResponse { _ = try ATProtoWebSocketFrameDecoder.decodeFrame(Data(Self.errorHeader)) }
        #expect(message?.hasPrefix("CBOR preflight failed for error payload:") == true)
    }

    @Test("Header-only frame reports a missing payload")
    func headerOnly() {
        let message = Self.invalidResponse { _ = try ATProtoWebSocketFrameDecoder.decodeFrame(Data(Self.commitHeader)) }
        #expect(message == "Missing payload in WebSocket frame")
    }

    @Test("Payload with trailing bytes fails the payload preflight")
    func payloadTrailingBytes() {
        let frame = Data(Self.commitHeader + Self.map([("a", [0x01])]) + [0x00])
        let message = Self.invalidResponse { _ = try ATProtoWebSocketFrameDecoder.decodeFrame(frame) }
        #expect(message?.hasPrefix("CBOR preflight failed for payload:") == true)
    }

    @Test("Non-canonical header fails the header preflight")
    func nonCanonicalHeader() {
        let header = Self.map([("op", [0x01]), ("t", Self.text("#commit"))])
        let frame = Data(header + Self.map([("a", [0x01])]))
        let message = Self.invalidResponse { _ = try ATProtoWebSocketFrameDecoder.decodeFrame(frame) }
        #expect(message?.hasPrefix("CBOR preflight failed for header:") == true)
    }

    @Test("Empty frame is rejected before any copy")
    func emptyFrame() {
        let message = Self.invalidResponse { _ = try ATProtoWebSocketFrameDecoder.decodeFrame(Data()) }
        #expect(message == "Empty WebSocket frame")
    }
}
