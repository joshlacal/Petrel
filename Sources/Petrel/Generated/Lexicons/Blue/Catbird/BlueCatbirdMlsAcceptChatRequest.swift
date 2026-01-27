import Foundation

// lexicon: 1, id: blue.catbird.mls.acceptChatRequest

public enum BlueCatbirdMlsAcceptChatRequest {
    public static let typeIdentifier = "blue.catbird.mls.acceptChatRequest"

    public struct DeliveredMessage: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.acceptChatRequest#deliveredMessage"
        public let id: String
        public let ciphertext: Bytes
        public let paddedSize: Int
        public let sequence: Int
        public let ephPubKey: Bytes?

        /// Standard initializer
        public init(
            id: String, ciphertext: Bytes, paddedSize: Int, sequence: Int, ephPubKey: Bytes?
        ) {
            self.id = id
            self.ciphertext = ciphertext
            self.paddedSize = paddedSize
            self.sequence = sequence
            self.ephPubKey = ephPubKey
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                id = try container.decode(String.self, forKey: .id)

            } catch {
                LogManager.logError("Decoding error for required property 'id': \(error)")

                throw error
            }
            do {
                ciphertext = try container.decode(Bytes.self, forKey: .ciphertext)

            } catch {
                LogManager.logError("Decoding error for required property 'ciphertext': \(error)")

                throw error
            }
            do {
                paddedSize = try container.decode(Int.self, forKey: .paddedSize)

            } catch {
                LogManager.logError("Decoding error for required property 'paddedSize': \(error)")

                throw error
            }
            do {
                sequence = try container.decode(Int.self, forKey: .sequence)

            } catch {
                LogManager.logError("Decoding error for required property 'sequence': \(error)")

                throw error
            }
            do {
                ephPubKey = try container.decodeIfPresent(Bytes.self, forKey: .ephPubKey)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'ephPubKey': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(id, forKey: .id)

            try container.encode(ciphertext, forKey: .ciphertext)

            try container.encode(paddedSize, forKey: .paddedSize)

            try container.encode(sequence, forKey: .sequence)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(ephPubKey, forKey: .ephPubKey)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(ciphertext)
            hasher.combine(paddedSize)
            hasher.combine(sequence)
            if let value = ephPubKey {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if id != other.id {
                return false
            }

            if ciphertext != other.ciphertext {
                return false
            }

            if paddedSize != other.paddedSize {
                return false
            }

            if sequence != other.sequence {
                return false
            }

            if ephPubKey != other.ephPubKey {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)

            let ciphertextValue = try ciphertext.toCBORValue()
            map = map.adding(key: "ciphertext", value: ciphertextValue)

            let paddedSizeValue = try paddedSize.toCBORValue()
            map = map.adding(key: "paddedSize", value: paddedSizeValue)

            let sequenceValue = try sequence.toCBORValue()
            map = map.adding(key: "sequence", value: sequenceValue)

            if let value = ephPubKey {
                // Encode optional property even if it's an empty array for CBOR

                let ephPubKeyValue = try value.toCBORValue()
                map = map.adding(key: "ephPubKey", value: ephPubKeyValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case ciphertext
            case paddedSize
            case sequence
            case ephPubKey
        }
    }

    public struct Input: ATProtocolCodable {
        public let requestId: String
        public let welcomeData: Bytes?

        /// Standard public initializer
        public init(requestId: String, welcomeData: Bytes? = nil) {
            self.requestId = requestId
            self.welcomeData = welcomeData
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            requestId = try container.decode(String.self, forKey: .requestId)

            welcomeData = try container.decodeIfPresent(Bytes.self, forKey: .welcomeData)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(requestId, forKey: .requestId)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(welcomeData, forKey: .welcomeData)
        }

        private enum CodingKeys: String, CodingKey {
            case requestId
            case welcomeData
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let requestIdValue = try requestId.toCBORValue()
            map = map.adding(key: "requestId", value: requestIdValue)

            if let value = welcomeData {
                // Encode optional property even if it's an empty array for CBOR
                let welcomeDataValue = try value.toCBORValue()
                map = map.adding(key: "welcomeData", value: welcomeDataValue)
            }

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let convoId: String

        public let heldMessages: [DeliveredMessage]

        public let acceptedAt: ATProtocolDate

        /// Standard public initializer
        public init(
            convoId: String,

            heldMessages: [DeliveredMessage],

            acceptedAt: ATProtocolDate

        ) {
            self.convoId = convoId

            self.heldMessages = heldMessages

            self.acceptedAt = acceptedAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            convoId = try container.decode(String.self, forKey: .convoId)

            heldMessages = try container.decode([DeliveredMessage].self, forKey: .heldMessages)

            acceptedAt = try container.decode(ATProtocolDate.self, forKey: .acceptedAt)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(convoId, forKey: .convoId)

            try container.encode(heldMessages, forKey: .heldMessages)

            try container.encode(acceptedAt, forKey: .acceptedAt)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)

            let heldMessagesValue = try heldMessages.toCBORValue()
            map = map.adding(key: "heldMessages", value: heldMessagesValue)

            let acceptedAtValue = try acceptedAt.toCBORValue()
            map = map.adding(key: "acceptedAt", value: acceptedAtValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case heldMessages
            case acceptedAt
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case requestNotFound = "RequestNotFound."
        case requestExpired = "RequestExpired."
        case alreadyProcessed = "AlreadyProcessed."
        public var description: String {
            return rawValue
        }

        public var errorName: String {
            // Extract just the error name from the raw value
            let parts = rawValue.split(separator: ".")
            return String(parts.first ?? "")
        }
    }
}

public extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - acceptChatRequest

    /// Accept a chat request, create MLS group, and deliver held messages
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func acceptChatRequest(
        input: BlueCatbirdMlsAcceptChatRequest.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsAcceptChatRequest.Output?) {
        let endpoint = "blue.catbird.mls.acceptChatRequest"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.acceptChatRequest")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(BlueCatbirdMlsAcceptChatRequest.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.acceptChatRequest: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
