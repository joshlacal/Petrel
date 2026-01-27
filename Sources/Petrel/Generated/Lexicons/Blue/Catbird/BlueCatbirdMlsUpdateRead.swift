import Foundation

// lexicon: 1, id: blue.catbird.mls.updateRead

public enum BlueCatbirdMlsUpdateRead {
    public static let typeIdentifier = "blue.catbird.mls.updateRead"
    public struct Input: ATProtocolCodable {
        public let convoId: String
        public let messageId: String?

        /// Standard public initializer
        public init(convoId: String, messageId: String? = nil) {
            self.convoId = convoId
            self.messageId = messageId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            convoId = try container.decode(String.self, forKey: .convoId)

            messageId = try container.decodeIfPresent(String.self, forKey: .messageId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(convoId, forKey: .convoId)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(messageId, forKey: .messageId)
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case messageId
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)

            if let value = messageId {
                // Encode optional property even if it's an empty array for CBOR
                let messageIdValue = try value.toCBORValue()
                map = map.adding(key: "messageId", value: messageIdValue)
            }

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let readAt: ATProtocolDate

        /// Standard public initializer
        public init(
            readAt: ATProtocolDate

        ) {
            self.readAt = readAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            readAt = try container.decode(ATProtocolDate.self, forKey: .readAt)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(readAt, forKey: .readAt)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let readAtValue = try readAt.toCBORValue()
            map = map.adding(key: "readAt", value: readAtValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case readAt
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case convoNotFound = "ConvoNotFound.Conversation not found"
        case notMember = "NotMember.Caller is not a member of this conversation"
        case messageNotFound = "MessageNotFound.Specified message not found"
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
    // MARK: - updateRead

    /// Mark MLS messages as read Mark messages as read in an MLS conversation. If messageId is omitted, marks all messages in the conversation as read.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func updateRead(
        input: BlueCatbirdMlsUpdateRead.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsUpdateRead.Output?) {
        let endpoint = "blue.catbird.mls.updateRead"

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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.updateRead")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsUpdateRead.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.updateRead: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
