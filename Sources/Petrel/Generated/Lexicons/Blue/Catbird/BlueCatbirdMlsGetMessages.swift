import Foundation

// lexicon: 1, id: blue.catbird.mls.getMessages

public enum BlueCatbirdMlsGetMessages {
    public static let typeIdentifier = "blue.catbird.mls.getMessages"

    public struct GapInfo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.getMessages#gapInfo"
        public let hasGaps: Bool
        public let missingSeqs: [Int]
        public let totalMessages: Int

        /// Standard initializer
        public init(
            hasGaps: Bool, missingSeqs: [Int], totalMessages: Int
        ) {
            self.hasGaps = hasGaps
            self.missingSeqs = missingSeqs
            self.totalMessages = totalMessages
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                hasGaps = try container.decode(Bool.self, forKey: .hasGaps)

            } catch {
                LogManager.logError("Decoding error for required property 'hasGaps': \(error)")

                throw error
            }
            do {
                missingSeqs = try container.decode([Int].self, forKey: .missingSeqs)

            } catch {
                LogManager.logError("Decoding error for required property 'missingSeqs': \(error)")

                throw error
            }
            do {
                totalMessages = try container.decode(Int.self, forKey: .totalMessages)

            } catch {
                LogManager.logError("Decoding error for required property 'totalMessages': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(hasGaps, forKey: .hasGaps)

            try container.encode(missingSeqs, forKey: .missingSeqs)

            try container.encode(totalMessages, forKey: .totalMessages)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(hasGaps)
            hasher.combine(missingSeqs)
            hasher.combine(totalMessages)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if hasGaps != other.hasGaps {
                return false
            }

            if missingSeqs != other.missingSeqs {
                return false
            }

            if totalMessages != other.totalMessages {
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

            let hasGapsValue = try hasGaps.toCBORValue()
            map = map.adding(key: "hasGaps", value: hasGapsValue)

            let missingSeqsValue = try missingSeqs.toCBORValue()
            map = map.adding(key: "missingSeqs", value: missingSeqsValue)

            let totalMessagesValue = try totalMessages.toCBORValue()
            map = map.adding(key: "totalMessages", value: totalMessagesValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case hasGaps
            case missingSeqs
            case totalMessages
        }
    }

    public struct Parameters: Parametrizable {
        public let convoId: String
        public let limit: Int?
        public let sinceSeq: Int?

        public init(
            convoId: String,
            limit: Int? = nil,
            sinceSeq: Int? = nil
        ) {
            self.convoId = convoId
            self.limit = limit
            self.sinceSeq = sinceSeq
        }
    }

    public struct Output: ATProtocolCodable {
        public let messages: [BlueCatbirdMlsDefs.MessageView]

        public let lastSeq: Int?

        public let gapInfo: GapInfo?

        /// Standard public initializer
        public init(
            messages: [BlueCatbirdMlsDefs.MessageView],

            lastSeq: Int? = nil,

            gapInfo: GapInfo? = nil

        ) {
            self.messages = messages

            self.lastSeq = lastSeq

            self.gapInfo = gapInfo
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            messages = try container.decode([BlueCatbirdMlsDefs.MessageView].self, forKey: .messages)

            lastSeq = try container.decodeIfPresent(Int.self, forKey: .lastSeq)

            gapInfo = try container.decodeIfPresent(GapInfo.self, forKey: .gapInfo)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(messages, forKey: .messages)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(lastSeq, forKey: .lastSeq)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(gapInfo, forKey: .gapInfo)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let messagesValue = try messages.toCBORValue()
            map = map.adding(key: "messages", value: messagesValue)

            if let value = lastSeq {
                // Encode optional property even if it's an empty array for CBOR
                let lastSeqValue = try value.toCBORValue()
                map = map.adding(key: "lastSeq", value: lastSeqValue)
            }

            if let value = gapInfo {
                // Encode optional property even if it's an empty array for CBOR
                let gapInfoValue = try value.toCBORValue()
                map = map.adding(key: "gapInfo", value: gapInfoValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case messages
            case lastSeq
            case gapInfo
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case convoNotFound = "ConvoNotFound.Conversation not found"
        case notMember = "NotMember.Caller is not a member of the conversation"
        case invalidCursor = "InvalidCursor.sinceSeq parameter is invalid or exceeds available messages"
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
    // MARK: - getMessages

    /// Retrieve messages from an MLS conversation. Messages are GUARANTEED to be returned in MLS sequential order (epoch ASC, seq ASC). Clients MUST process messages in this order for proper MLS decryption.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getMessages(input: BlueCatbirdMlsGetMessages.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetMessages.Output?) {
        let endpoint = "blue.catbird.mls.getMessages"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getMessages")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetMessages.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getMessages: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
