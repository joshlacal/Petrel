import Foundation
import SwiftCBOR

/// WebSocket subscription support for NetworkService
extension NetworkServiceImpl {
    public func subscribe<Message: Codable>(
        endpoint: String,
        parameters: (any Parametrizable)?
    ) async throws -> AsyncThrowingStream<Message, Error> {
        // Build WebSocket URL
        var urlComponents = URLComponents()
        urlComponents.scheme = "wss" // Always use secure WebSocket
        urlComponents.host = pdsURL.host
        urlComponents.path = "/xrpc/\(endpoint)"

        // Add query parameters if provided
        if let params = parameters {
            urlComponents.queryItems = try params.asQueryItems()
        }

        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }

        // Create WebSocket task
        let session = URLSession.shared
        let webSocketTask = session.webSocketTask(with: url)

        // Connect
        webSocketTask.resume()

        // Create async stream
        return AsyncThrowingStream { continuation in
            // Start receiving messages
            Task {
                do {
                    while !Task.isCancelled {
                        let message = try await webSocketTask.receive()

                        switch message {
                        case let .data(data):
                            // Parse binary WebSocket frame
                            if let decodedMessage = try? self.decodeSubscriptionFrame(data, as: Message.self) {
                                continuation.yield(decodedMessage)
                            }

                        case .string:
                            // ATProtocol subscriptions use binary frames, not text
                            // If we get text, it might be an error
                            LogManager.logWarning("Received unexpected text frame on subscription")

                        @unknown default:
                            break
                        }
                    }
                } catch {
                    // Check if it's a clean close
                    if let urlError = error as? URLError,
                       urlError.code == .cancelled
                    {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }

            // Handle cancellation
            continuation.onTermination = { @Sendable _ in
                webSocketTask.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    /// Decode a subscription WebSocket frame
    /// Each frame contains two DAG-CBOR objects: header + payload
    private func decodeSubscriptionFrame<Message: Codable>(
        _ data: Data,
        as messageType: Message.Type
    ) throws -> Message {
        // Parse the frame: it contains two concatenated CBOR objects
        var offset = 0

        // 1. Decode header
        let headerCBOR = try CBOR.decode([UInt8](data[offset...]))
        guard case let .map(headerMap) = headerCBOR else {
            throw NetworkError.invalidResponse(description: "Invalid header format")
        }

        // Extract header fields
        let opKey = CBOR.utf8String("op")
        let tKey = CBOR.utf8String("t")

        guard let opValue = headerMap[opKey],
              case let .unsignedInt(op) = opValue
        else {
            throw NetworkError.invalidResponse(description: "Missing or invalid 'op' in header")
        }

        // op = 1 means regular message, op = -1 means error
        if op == UInt64(bitPattern: -1) {
            // Error message - decode and throw
            // Move offset past header to get payload
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

        // Get message type from header
        guard let tValue = headerMap[tKey],
              case let .utf8String(messageTypeName) = tValue
        else {
            throw NetworkError.invalidResponse(description: "Missing or invalid 't' in header")
        }

        // 2. Decode payload
        // Move offset past header
        let headerData = try headerCBOR.encode()
        offset += headerData.count

        // Decode payload as DAG-CBOR
        let payloadData = data[offset...]
        let payloadCBOR = try CBOR.decode([UInt8](payloadData))

        // Convert CBOR to JSON for standard Codable decoding
        let jsonData = try cborToJSON(payloadCBOR)

        // Add $type field to the JSON
        var jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] ?? [:]
        jsonObject["$type"] = messageTypeName
        let finalJSONData = try JSONSerialization.data(withJSONObject: jsonObject)

        // Decode using standard JSONDecoder
        let decoder = JSONDecoder()
        return try decoder.decode(Message.self, from: finalJSONData)
    }

    /// Convert CBOR to JSON for Codable compatibility
    private func cborToJSON(_ cbor: CBOR) throws -> Data {
        let jsonValue = try cborToJSONValue(cbor)
        return try JSONSerialization.data(withJSONObject: jsonValue)
    }

    /// Recursively convert CBOR values to JSON-compatible values
    private func cborToJSONValue(_ cbor: CBOR) throws -> Any {
        switch cbor {
        case let .unsignedInt(value):
            return Int(value)
        case let .negativeInt(value):
            return -1 - Int(value)
        case let .byteString(bytes):
            // Encode as base64 for JSON
            return ["$bytes": Data(bytes).base64EncodedString()]
        case let .utf8String(string):
            return string
        case let .array(items):
            return try items.map { try cborToJSONValue($0) }
        case let .map(map):
            var result: [String: Any] = [:]
            for (key, value) in map {
                guard case let .utf8String(keyString) = key else {
                    throw NetworkError.invalidResponse(description: "Non-string map key")
                }
                result[keyString] = try cborToJSONValue(value)
            }
            return result
        case let .tagged(tag, value):
            if tag.rawValue == 42 {
                // CID link
                guard case let .byteString(bytes) = value else {
                    throw NetworkError.invalidResponse(description: "Invalid CID encoding")
                }
                let cid = try CID(bytes: Data(bytes))
                return ["$link": cid.toString()]
            }
            // Other tags - just decode the inner value
            return try cborToJSONValue(value)
        case let .simple(simple):
            switch simple {
            case let .bool(bool):
                return bool
            case .null:
                return NSNull()
            default:
                throw NetworkError.invalidResponse(description: "Unsupported CBOR simple value")
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

// Helper extension for Parametrizable to convert to URLQueryItems
extension Parametrizable {
    func asQueryItems() throws -> [URLQueryItem] {
        let mirror = Mirror(reflecting: self)
        var items: [URLQueryItem] = []

        for child in mirror.children {
            guard let label = child.label else { continue }

            // Skip nil optionals
            if case Optional<Any>.none = child.value {
                continue
            }

            // Convert value to string
            let valueString: String
            if let queryConvertible = child.value as? QueryParameterConvertible {
                if let item = queryConvertible.asQueryItem(name: label) {
                    items.append(item)
                }
                continue
            } else if let optionalValue = child.value as? (any OptionalProtocol) {
                if let unwrapped = optionalValue.wrappedValue {
                    valueString = "\(unwrapped)"
                } else {
                    continue
                }
            } else {
                valueString = "\(child.value)"
            }

            items.append(URLQueryItem(name: label, value: valueString))
        }

        return items
    }
}

// Protocol to help unwrap optionals
private protocol OptionalProtocol {
    var wrappedValue: Any? { get }
}

extension Optional: OptionalProtocol {
    var wrappedValue: Any? {
        switch self {
        case let .some(value):
            return value
        case .none:
            return nil
        }
    }
}
