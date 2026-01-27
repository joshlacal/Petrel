import Foundation
import SwiftCBOR

public enum ATProtoWebSocketFrameDecoder {
    public struct DecodedFrame {
        public let messageType: String
        public let jsonData: Data

        public init(messageType: String, jsonData: Data) {
            self.messageType = messageType
            self.jsonData = jsonData
        }
    }

    /// Decode a subscription WebSocket frame containing two DAG-CBOR objects.
    public static func decodeFrame(_ data: Data) throws -> DecodedFrame {
        var offset = 0

        guard offset < data.count else {
            throw NetworkError.invalidResponse(description: "Empty WebSocket frame")
        }

        let headerCBOR = try CBOR.decode([UInt8](data[offset...]))
        guard case let .map(headerMap) = headerCBOR else {
            throw NetworkError.invalidResponse(description: "Invalid header format")
        }

        let opKey = CBOR.utf8String("op")
        let tKey = CBOR.utf8String("t")

        guard let opValue = headerMap[opKey],
              case let .unsignedInt(op) = opValue
        else {
            throw NetworkError.invalidResponse(description: "Missing or invalid 'op' in header")
        }

        if op == UInt64(bitPattern: -1) {
            let headerData = try headerCBOR.encode()
            offset += headerData.count

            let payloadData = data[offset...]
            let errorPayload = try CBOR.decode([UInt8](payloadData))

            if case let .map(errorMap) = errorPayload,
               let errorNameCBOR = errorMap[CBOR.utf8String("error")],
               case let .utf8String(errorName) = errorNameCBOR
            {
                throw NetworkError.serverError(code: 400, message: errorName)
            }
            throw NetworkError.invalidResponse(description: "Unknown error frame")
        }

        guard op == 1 else {
            throw NetworkError.invalidResponse(description: "Unknown operation code: \(op)")
        }

        guard let tValue = headerMap[tKey],
              case let .utf8String(messageTypeName) = tValue
        else {
            throw NetworkError.invalidResponse(description: "Missing message type in header")
        }

        let headerData = try headerCBOR.encode()
        offset += headerData.count

        guard offset < data.count else {
            throw NetworkError.invalidResponse(description: "Missing payload in WebSocket frame")
        }

        let payloadData = data[offset...]
        guard let payloadCBOR = try? CBOR.decode([UInt8](payloadData)) else {
            throw NetworkError.invalidResponse(description: "Failed to decode CBOR payload")
        }

        let jsonValue = try cborToJSONValue(payloadCBOR)
        guard var jsonObject = jsonValue as? [String: Any] else {
            throw NetworkError.invalidResponse(description: "Payload is not a JSON object")
        }

        jsonObject["$type"] = messageTypeName
        let jsonData = try JSONSerialization.data(withJSONObject: jsonObject)

        return DecodedFrame(messageType: messageTypeName, jsonData: jsonData)
    }

    private static func cborToJSONValue(_ cbor: CBOR) throws -> Any {
        switch cbor {
        case let .unsignedInt(value):
            return Int(value)
        case let .negativeInt(value):
            return -1 - Int(value)
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
                guard case let .byteString(bytes) = value else {
                    throw NetworkError.invalidResponse(description: "Invalid CID encoding")
                }
                let cid = try CID(bytes: Data(bytes))
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
