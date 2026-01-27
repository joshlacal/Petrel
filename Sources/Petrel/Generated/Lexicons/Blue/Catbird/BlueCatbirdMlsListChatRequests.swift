import Foundation

// lexicon: 1, id: blue.catbird.mls.listChatRequests

public enum BlueCatbirdMlsListChatRequests {
    public static let typeIdentifier = "blue.catbird.mls.listChatRequests"

    public struct ChatRequest: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.listChatRequests#chatRequest"
        public let id: String
        public let senderDid: String
        public let status: String
        public let createdAt: ATProtocolDate
        public let expiresAt: ATProtocolDate
        public let previewText: String?
        public let messageCount: Int?
        public let isGroupInvite: Bool?
        public let groupId: String?

        public init(
            id: String, senderDid: String, status: String, createdAt: ATProtocolDate, expiresAt: ATProtocolDate, previewText: String?, messageCount: Int?, isGroupInvite: Bool?, groupId: String?
        ) {
            self.id = id
            self.senderDid = senderDid
            self.status = status
            self.createdAt = createdAt
            self.expiresAt = expiresAt
            self.previewText = previewText
            self.messageCount = messageCount
            self.isGroupInvite = isGroupInvite
            self.groupId = groupId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                id = try container.decode(String.self, forKey: .id)
            } catch {
                LogManager.logError("Decoding error for required property 'id': \(error)")
                throw error
            }
            do {
                senderDid = try container.decode(String.self, forKey: .senderDid)
            } catch {
                LogManager.logError("Decoding error for required property 'senderDid': \(error)")
                throw error
            }
            do {
                status = try container.decode(String.self, forKey: .status)
            } catch {
                LogManager.logError("Decoding error for required property 'status': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
            do {
                expiresAt = try container.decode(ATProtocolDate.self, forKey: .expiresAt)
            } catch {
                LogManager.logError("Decoding error for required property 'expiresAt': \(error)")
                throw error
            }
            do {
                previewText = try container.decodeIfPresent(String.self, forKey: .previewText)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'previewText': \(error)")
                throw error
            }
            do {
                messageCount = try container.decodeIfPresent(Int.self, forKey: .messageCount)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'messageCount': \(error)")
                throw error
            }
            do {
                isGroupInvite = try container.decodeIfPresent(Bool.self, forKey: .isGroupInvite)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'isGroupInvite': \(error)")
                throw error
            }
            do {
                groupId = try container.decodeIfPresent(String.self, forKey: .groupId)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'groupId': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(id, forKey: .id)
            try container.encode(senderDid, forKey: .senderDid)
            try container.encode(status, forKey: .status)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(expiresAt, forKey: .expiresAt)
            try container.encodeIfPresent(previewText, forKey: .previewText)
            try container.encodeIfPresent(messageCount, forKey: .messageCount)
            try container.encodeIfPresent(isGroupInvite, forKey: .isGroupInvite)
            try container.encodeIfPresent(groupId, forKey: .groupId)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(senderDid)
            hasher.combine(status)
            hasher.combine(createdAt)
            hasher.combine(expiresAt)
            if let value = previewText {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = messageCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = isGroupInvite {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = groupId {
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
            if senderDid != other.senderDid {
                return false
            }
            if status != other.status {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if expiresAt != other.expiresAt {
                return false
            }
            if previewText != other.previewText {
                return false
            }
            if messageCount != other.messageCount {
                return false
            }
            if isGroupInvite != other.isGroupInvite {
                return false
            }
            if groupId != other.groupId {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)
            let senderDidValue = try senderDid.toCBORValue()
            map = map.adding(key: "senderDid", value: senderDidValue)
            let statusValue = try status.toCBORValue()
            map = map.adding(key: "status", value: statusValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            let expiresAtValue = try expiresAt.toCBORValue()
            map = map.adding(key: "expiresAt", value: expiresAtValue)
            if let value = previewText {
                let previewTextValue = try value.toCBORValue()
                map = map.adding(key: "previewText", value: previewTextValue)
            }
            if let value = messageCount {
                let messageCountValue = try value.toCBORValue()
                map = map.adding(key: "messageCount", value: messageCountValue)
            }
            if let value = isGroupInvite {
                let isGroupInviteValue = try value.toCBORValue()
                map = map.adding(key: "isGroupInvite", value: isGroupInviteValue)
            }
            if let value = groupId {
                let groupIdValue = try value.toCBORValue()
                map = map.adding(key: "groupId", value: groupIdValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case senderDid
            case status
            case createdAt
            case expiresAt
            case previewText
            case messageCount
            case isGroupInvite
            case groupId
        }
    }

    public struct Parameters: Parametrizable {
        public let cursor: String?
        public let limit: Int?
        public let status: String?

        public init(
            cursor: String? = nil,
            limit: Int? = nil,
            status: String? = nil
        ) {
            self.cursor = cursor
            self.limit = limit
            self.status = status
        }
    }

    public struct Output: ATProtocolCodable {
        public let requests: [ChatRequest]

        public let cursor: String?

        /// Standard public initializer
        public init(
            requests: [ChatRequest],

            cursor: String? = nil

        ) {
            self.requests = requests

            self.cursor = cursor
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            requests = try container.decode([ChatRequest].self, forKey: .requests)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(requests, forKey: .requests)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let requestsValue = try requests.toCBORValue()
            map = map.adding(key: "requests", value: requestsValue)

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case requests
            case cursor
        }
    }
}

public extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - listChatRequests

    /// List pending chat requests received by the authenticated user
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func listChatRequests(input: BlueCatbirdMlsListChatRequests.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsListChatRequests.Output?) {
        let endpoint = "blue.catbird.mls.listChatRequests"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.listChatRequests")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsListChatRequests.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.listChatRequests: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
