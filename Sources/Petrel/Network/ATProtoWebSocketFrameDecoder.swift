import Foundation
import SwiftCBOR

/// An error frame (`op: -1`) received on an AT Protocol event stream.
///
/// The event-stream specification defines the payload as `{error, message?}` and requires the
/// stream to be closed right after the frame. Well-known error names get their own case so
/// callers can match on them directly:
///
/// ```swift
/// do {
///     for try await event in subscription.events() { … }
/// } catch EventStreamError.futureCursor {
///     // The stored cursor is ahead of the server's sequence; an operator has to decide.
/// }
/// ```
public enum EventStreamError: Error, Sendable, Equatable {
    /// `FutureCursor`: the requested cursor is higher than the server's current sequence.
    case futureCursor(message: String?)
    /// `ConsumerTooSlow`: the client did not keep up with the stream and was disconnected.
    case consumerTooSlow(message: String?)
    /// Any other error name.
    case other(name: String, message: String?)

    /// Classifies an error frame payload by its `error` name.
    public init(name: String, message: String?) {
        switch name {
        case "FutureCursor": self = .futureCursor(message: message)
        case "ConsumerTooSlow": self = .consumerTooSlow(message: message)
        default: self = .other(name: name, message: message)
        }
    }

    /// The wire `error` name, without namespace or `#` prefix.
    public var name: String {
        switch self {
        case .futureCursor: "FutureCursor"
        case .consumerTooSlow: "ConsumerTooSlow"
        case let .other(name, _): name
        }
    }

    /// The optional human-readable `message` of the error frame.
    public var message: String? {
        switch self {
        case let .futureCursor(message), let .consumerTooSlow(message), let .other(_, message): message
        }
    }
}

public enum ATProtoWebSocketFrameDecoder {
    /// Hard upper bound for one event-stream WebSocket frame (sync specification: 5 MB).
    ///
    /// Transports must be configured to accept messages of at least this size;
    /// `URLSessionWebSocketTask.maximumMessageSize` defaults to 1 MiB.
    public static let maximumFrameBytes = 5_000_000

    public struct DecodedFrame: Sendable {
        public let messageType: String
        public let jsonData: Data
        /// The payload's `seq` field when it is present and an integer; `nil` for unsequenced
        /// messages such as `#info`.
        public let sequence: Int64?

        public init(messageType: String, jsonData: Data) {
            self.init(messageType: messageType, jsonData: jsonData, sequence: nil)
        }

        /// Creates a decoded frame that also carries the payload sequence number.
        public init(messageType: String, jsonData: Data, sequence: Int64?) {
            self.messageType = messageType
            self.jsonData = jsonData
            self.sequence = sequence
        }
    }

    /// What one binary event-stream frame contains.
    public enum Frame: Sendable {
        /// A regular message (`op: 1`). The payload is re-encoded as lexicon JSON with `$type` set.
        case message(DecodedFrame)
        /// An error frame (`op: -1`). The stream must be closed after it.
        case error(EventStreamError)
        /// A frame whose header carries an `op` this decoder does not know. The specification says
        /// clients should ignore such frames instead of failing.
        case unknownOperation(Int64)
    }

    /// Decodes a subscription WebSocket frame: two concatenated DAG-CBOR objects, header then payload.
    ///
    /// Unknown header fields are ignored. Invalid framing or CBOR throws, and the caller should
    /// drop the connection. Unknown `op` values are returned as ``Frame/unknownOperation(_:)``
    /// so the caller can skip the frame.
    public static func decode(_ data: Data, defaultLexicon: String? = nil) throws -> Frame {
        guard !data.isEmpty else {
            throw NetworkError.invalidResponse(description: "Empty WebSocket frame")
        }
        guard data.count <= maximumFrameBytes else {
            throw NetworkError.invalidResponse(description: "WebSocket frame exceeds the 5 MB event stream limit")
        }

        do {
            try DAGCBOR.decodeCBORPreflight(data, allowTrailingBytes: true)
        } catch {
            throw NetworkError.invalidResponse(description: "CBOR preflight failed for header: \(error.localizedDescription)")
        }

        guard let headerCBOR = try? CBOR.decode([UInt8](data)) else {
            throw NetworkError.invalidResponse(description: "Invalid header format")
        }
        guard case let .map(headerMap) = headerCBOR else {
            throw NetworkError.invalidResponse(description: "Invalid header format")
        }

        let operation: Int64
        switch headerMap[CBOR.utf8String("op")] {
        case let .unsignedInt(value)? where value <= UInt64(Int64.max):
            operation = Int64(value)
        case let .negativeInt(value)? where value <= UInt64(Int64.max):
            operation = -1 - Int64(value)
        default:
            throw NetworkError.invalidResponse(description: "Missing or invalid 'op' in header")
        }

        // The preflight guarantees canonical DAG-CBOR, so re-encoding reproduces the header length.
        let payloadData = Data(data.dropFirst(headerCBOR.encode().count))

        switch operation {
        case -1:
            let errorPayload = try decodePayload(payloadData, role: "error payload")
            guard case let .map(errorMap) = errorPayload,
                  case let .utf8String(errorName)? = errorMap[CBOR.utf8String("error")]
            else {
                throw NetworkError.invalidResponse(description: "Error frame without an error name")
            }
            var message: String?
            if case let .utf8String(text)? = errorMap[CBOR.utf8String("message")] {
                message = text
            }
            return .error(EventStreamError(name: errorName, message: message))

        case 1:
            guard case let .utf8String(messageTypeName)? = headerMap[CBOR.utf8String("t")] else {
                throw NetworkError.invalidResponse(description: "Missing message type in header")
            }
            let payloadCBOR = try decodePayload(payloadData, role: "payload")
            guard var jsonObject = try cborToJSONValue(payloadCBOR) as? [String: Any] else {
                throw NetworkError.invalidResponse(description: "Payload is not a JSON object")
            }

            var resolvedType = messageTypeName
            if resolvedType.hasPrefix("#"), let defaultLexicon {
                resolvedType = defaultLexicon + resolvedType
            }

            var sequence: Int64?
            if let seq = jsonObject["seq"] as? Int {
                sequence = Int64(seq)
            }

            jsonObject["$type"] = resolvedType
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject)
            return .message(DecodedFrame(messageType: resolvedType, jsonData: jsonData, sequence: sequence))

        default:
            return .unknownOperation(operation)
        }
    }

    /// Decode a subscription WebSocket frame containing two DAG-CBOR objects.
    ///
    /// Error frames (`op: -1`) throw ``EventStreamError``. A frame with an unknown `op` throws
    /// `NetworkError.invalidResponse` because this method cannot express "skip"; consumers that
    /// follow the specification's ignore rule call ``decode(_:defaultLexicon:)`` instead.
    public static func decodeFrame(_ data: Data, defaultLexicon: String? = nil) throws -> DecodedFrame {
        switch try decode(data, defaultLexicon: defaultLexicon) {
        case let .message(frame):
            return frame
        case let .error(error):
            throw error
        case let .unknownOperation(operation):
            throw NetworkError.invalidResponse(description: "Unknown operation code: \(operation)")
        }
    }

    private static func decodePayload(_ payloadData: Data, role: String) throws -> CBOR {
        guard !payloadData.isEmpty else {
            throw NetworkError.invalidResponse(description: "Missing payload in WebSocket frame")
        }
        do {
            try DAGCBOR.decodeCBORPreflight(payloadData)
        } catch {
            throw NetworkError.invalidResponse(description: "CBOR preflight failed for \(role): \(error.localizedDescription)")
        }
        guard let payload = try? CBOR.decode([UInt8](payloadData)) else {
            throw NetworkError.invalidResponse(description: "Failed to decode CBOR \(role)")
        }
        return payload
    }

    private static func cborToJSONValue(_ cbor: CBOR) throws -> Any {
        switch cbor {
        case let .unsignedInt(value):
            guard value <= UInt64(Int.max) else {
                throw NetworkError.invalidResponse(
                    description: "CBOR unsigned integer \(value) exceeds Int.max"
                )
            }
            return Int(value)
        case let .negativeInt(value):
            guard value <= UInt64(Int64.max) else {
                throw NetworkError.invalidResponse(
                    description: "CBOR negative integer argument \(value) exceeds Int64 boundary"
                )
            }
            let int64Val = -Int64(value) - 1
            guard int64Val >= Int64(Int.min) && int64Val <= Int64(Int.max) else {
                throw NetworkError.invalidResponse(
                    description: "CBOR negative integer \(int64Val) underflows Int.min"
                )
            }
            return Int(int64Val)
        case let .byteString(bytes):
            return ["$bytes": Data(bytes).base64EncodedString()]
        case let .utf8String(string):
            return string
        case let .array(items):
            return try items.map { try cborToJSONValue($0) }
        case let .map(map):
            var result: [String: Any] = [:]
            for (key, value) in map {
                guard case let .utf8String(keyString) = key else {
                    throw NetworkError.invalidResponse(description: "Non-string map key in CBOR")
                }
                result[keyString] = try cborToJSONValue(value)
            }
            return result
        case let .tagged(tag, value):
            if tag.rawValue == 42 {
                // DAG-CBOR cid-link: a byte string holding the multibase identity prefix 0x00
                // followed by the binary CID.
                guard case let .byteString(bytes) = value, bytes.first == 0x00 else {
                    throw NetworkError.invalidResponse(description: "Invalid CID encoding")
                }
                let cid = try CID(bytes: Data(bytes.dropFirst()))
                return ["$link": cid.string]
            }
            return try cborToJSONValue(value)
        case let .simple(value):
            switch value {
            case 20: return false
            case 21: return true
            case 22: return NSNull()
            default:
                throw NetworkError.invalidResponse(description: "Unsupported CBOR simple value: \(value)")
            }
        case let .boolean(bool):
            return bool
        case .null:
            return NSNull()
        case .undefined:
            return NSNull()
        case .half(_), .float(_), .double:
            throw NetworkError.invalidResponse(description: "Floating point not allowed in DAG-CBOR")
        case .break:
            throw NetworkError.invalidResponse(description: "Unexpected CBOR break")
        case .date:
            throw NetworkError.invalidResponse(description: "CBOR date type not supported")
        }
    }
}
