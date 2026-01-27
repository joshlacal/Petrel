import Foundation

// lexicon: 1, id: blue.catbird.mls.getExpectedConversations

public enum BlueCatbirdMlsGetExpectedConversations {
    public static let typeIdentifier = "blue.catbird.mls.getExpectedConversations"

    public struct ExpectedConversation: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.getExpectedConversations#expectedConversation"
        public let convoId: String
        public let name: String
        public let memberCount: Int
        public let shouldBeInGroup: Bool
        public let lastActivity: ATProtocolDate?
        public let needsRejoin: Bool?
        public let deviceInGroup: Bool?

        public init(
            convoId: String, name: String, memberCount: Int, shouldBeInGroup: Bool, lastActivity: ATProtocolDate?, needsRejoin: Bool?, deviceInGroup: Bool?
        ) {
            self.convoId = convoId
            self.name = name
            self.memberCount = memberCount
            self.shouldBeInGroup = shouldBeInGroup
            self.lastActivity = lastActivity
            self.needsRejoin = needsRejoin
            self.deviceInGroup = deviceInGroup
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                name = try container.decode(String.self, forKey: .name)
            } catch {
                LogManager.logError("Decoding error for required property 'name': \(error)")
                throw error
            }
            do {
                memberCount = try container.decode(Int.self, forKey: .memberCount)
            } catch {
                LogManager.logError("Decoding error for required property 'memberCount': \(error)")
                throw error
            }
            do {
                shouldBeInGroup = try container.decode(Bool.self, forKey: .shouldBeInGroup)
            } catch {
                LogManager.logError("Decoding error for required property 'shouldBeInGroup': \(error)")
                throw error
            }
            do {
                lastActivity = try container.decodeIfPresent(ATProtocolDate.self, forKey: .lastActivity)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'lastActivity': \(error)")
                throw error
            }
            do {
                needsRejoin = try container.decodeIfPresent(Bool.self, forKey: .needsRejoin)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'needsRejoin': \(error)")
                throw error
            }
            do {
                deviceInGroup = try container.decodeIfPresent(Bool.self, forKey: .deviceInGroup)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'deviceInGroup': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(name, forKey: .name)
            try container.encode(memberCount, forKey: .memberCount)
            try container.encode(shouldBeInGroup, forKey: .shouldBeInGroup)
            try container.encodeIfPresent(lastActivity, forKey: .lastActivity)
            try container.encodeIfPresent(needsRejoin, forKey: .needsRejoin)
            try container.encodeIfPresent(deviceInGroup, forKey: .deviceInGroup)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(convoId)
            hasher.combine(name)
            hasher.combine(memberCount)
            hasher.combine(shouldBeInGroup)
            if let value = lastActivity {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = needsRejoin {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = deviceInGroup {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if convoId != other.convoId {
                return false
            }
            if name != other.name {
                return false
            }
            if memberCount != other.memberCount {
                return false
            }
            if shouldBeInGroup != other.shouldBeInGroup {
                return false
            }
            if lastActivity != other.lastActivity {
                return false
            }
            if needsRejoin != other.needsRejoin {
                return false
            }
            if deviceInGroup != other.deviceInGroup {
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
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let nameValue = try name.toCBORValue()
            map = map.adding(key: "name", value: nameValue)
            let memberCountValue = try memberCount.toCBORValue()
            map = map.adding(key: "memberCount", value: memberCountValue)
            let shouldBeInGroupValue = try shouldBeInGroup.toCBORValue()
            map = map.adding(key: "shouldBeInGroup", value: shouldBeInGroupValue)
            if let value = lastActivity {
                let lastActivityValue = try value.toCBORValue()
                map = map.adding(key: "lastActivity", value: lastActivityValue)
            }
            if let value = needsRejoin {
                let needsRejoinValue = try value.toCBORValue()
                map = map.adding(key: "needsRejoin", value: needsRejoinValue)
            }
            if let value = deviceInGroup {
                let deviceInGroupValue = try value.toCBORValue()
                map = map.adding(key: "deviceInGroup", value: deviceInGroupValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case convoId
            case name
            case memberCount
            case shouldBeInGroup
            case lastActivity
            case needsRejoin
            case deviceInGroup
        }
    }

    public struct Parameters: Parametrizable {
        public let deviceId: String?

        public init(
            deviceId: String? = nil
        ) {
            self.deviceId = deviceId
        }
    }

    public struct Output: ATProtocolCodable {
        public let conversations: [ExpectedConversation]

        /// Standard public initializer
        public init(
            conversations: [ExpectedConversation]

        ) {
            self.conversations = conversations
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            conversations = try container.decode([ExpectedConversation].self, forKey: .conversations)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(conversations, forKey: .conversations)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let conversationsValue = try conversations.toCBORValue()
            map = map.adding(key: "conversations", value: conversationsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case conversations
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case unauthorized = "Unauthorized.Authentication required"
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
    // MARK: - getExpectedConversations

    /// Get list of conversations the user should be a member of but may be missing locally Returns conversations where the user is a member on the server but may not have local MLS state
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getExpectedConversations(input: BlueCatbirdMlsGetExpectedConversations.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetExpectedConversations.Output?) {
        let endpoint = "blue.catbird.mls.getExpectedConversations"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getExpectedConversations")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetExpectedConversations.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getExpectedConversations: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
