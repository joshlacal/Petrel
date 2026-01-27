import Foundation

// lexicon: 1, id: blue.catbird.mls.sendChatRequest

public enum BlueCatbirdMlsSendChatRequest {
    public static let typeIdentifier = "blue.catbird.mls.sendChatRequest"

    public struct HeldMessage: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.sendChatRequest#heldMessage"
        public let ciphertext: Bytes
        public let paddedSize: Int
        public let ephPubKey: Bytes?

        public init(
            ciphertext: Bytes, paddedSize: Int, ephPubKey: Bytes?
        ) {
            self.ciphertext = ciphertext
            self.paddedSize = paddedSize
            self.ephPubKey = ephPubKey
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
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
                ephPubKey = try container.decodeIfPresent(Bytes.self, forKey: .ephPubKey)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'ephPubKey': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(ciphertext, forKey: .ciphertext)
            try container.encode(paddedSize, forKey: .paddedSize)
            try container.encodeIfPresent(ephPubKey, forKey: .ephPubKey)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(ciphertext)
            hasher.combine(paddedSize)
            if let value = ephPubKey {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if ciphertext != other.ciphertext {
                return false
            }
            if paddedSize != other.paddedSize {
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let ciphertextValue = try ciphertext.toCBORValue()
            map = map.adding(key: "ciphertext", value: ciphertextValue)
            let paddedSizeValue = try paddedSize.toCBORValue()
            map = map.adding(key: "paddedSize", value: paddedSizeValue)
            if let value = ephPubKey {
                let ephPubKeyValue = try value.toCBORValue()
                map = map.adding(key: "ephPubKey", value: ephPubKeyValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case ciphertext
            case paddedSize
            case ephPubKey
        }
    }

    public struct Input: ATProtocolCodable {
        public let recipientDid: String
        public let previewText: String?
        public let heldMessages: [HeldMessage]?
        public let isGroupInvite: Bool?
        public let groupId: String?

        /// Standard public initializer
        public init(recipientDid: String, previewText: String? = nil, heldMessages: [HeldMessage]? = nil, isGroupInvite: Bool? = nil, groupId: String? = nil) {
            self.recipientDid = recipientDid
            self.previewText = previewText
            self.heldMessages = heldMessages
            self.isGroupInvite = isGroupInvite
            self.groupId = groupId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            recipientDid = try container.decode(String.self, forKey: .recipientDid)
            previewText = try container.decodeIfPresent(String.self, forKey: .previewText)
            heldMessages = try container.decodeIfPresent([HeldMessage].self, forKey: .heldMessages)
            isGroupInvite = try container.decodeIfPresent(Bool.self, forKey: .isGroupInvite)
            groupId = try container.decodeIfPresent(String.self, forKey: .groupId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(recipientDid, forKey: .recipientDid)
            try container.encodeIfPresent(previewText, forKey: .previewText)
            try container.encodeIfPresent(heldMessages, forKey: .heldMessages)
            try container.encodeIfPresent(isGroupInvite, forKey: .isGroupInvite)
            try container.encodeIfPresent(groupId, forKey: .groupId)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let recipientDidValue = try recipientDid.toCBORValue()
            map = map.adding(key: "recipientDid", value: recipientDidValue)
            if let value = previewText {
                let previewTextValue = try value.toCBORValue()
                map = map.adding(key: "previewText", value: previewTextValue)
            }
            if let value = heldMessages {
                let heldMessagesValue = try value.toCBORValue()
                map = map.adding(key: "heldMessages", value: heldMessagesValue)
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
            case recipientDid
            case previewText
            case heldMessages
            case isGroupInvite
            case groupId
        }
    }

    public struct Output: ATProtocolCodable {
        public let requestId: String

        public let status: String

        public let createdAt: ATProtocolDate

        public let expiresAt: ATProtocolDate

        public let convoId: String?

        /// Standard public initializer
        public init(
            requestId: String,

            status: String,

            createdAt: ATProtocolDate,

            expiresAt: ATProtocolDate,

            convoId: String? = nil

        ) {
            self.requestId = requestId

            self.status = status

            self.createdAt = createdAt

            self.expiresAt = expiresAt

            self.convoId = convoId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            requestId = try container.decode(String.self, forKey: .requestId)

            status = try container.decode(String.self, forKey: .status)

            createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

            expiresAt = try container.decode(ATProtocolDate.self, forKey: .expiresAt)

            convoId = try container.decodeIfPresent(String.self, forKey: .convoId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(requestId, forKey: .requestId)

            try container.encode(status, forKey: .status)

            try container.encode(createdAt, forKey: .createdAt)

            try container.encode(expiresAt, forKey: .expiresAt)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(convoId, forKey: .convoId)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let requestIdValue = try requestId.toCBORValue()
            map = map.adding(key: "requestId", value: requestIdValue)

            let statusValue = try status.toCBORValue()
            map = map.adding(key: "status", value: statusValue)

            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)

            let expiresAtValue = try expiresAt.toCBORValue()
            map = map.adding(key: "expiresAt", value: expiresAtValue)

            if let value = convoId {
                // Encode optional property even if it's an empty array for CBOR
                let convoIdValue = try value.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case requestId
            case status
            case createdAt
            case expiresAt
            case convoId
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case blockedByRecipient = "BlockedByRecipient."
        case rateLimited = "RateLimited."
        case recipientNotFound = "RecipientNotFound."
        case duplicateRequest = "DuplicateRequest."
        case selfRequest = "SelfRequest."
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
    // MARK: - sendChatRequest

    /// Send a chat request to a user not yet in conversation. The request holds encrypted message(s) until accepted.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func sendChatRequest(
        input: BlueCatbirdMlsSendChatRequest.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsSendChatRequest.Output?) {
        let endpoint = "blue.catbird.mls.sendChatRequest"

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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.sendChatRequest")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsSendChatRequest.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.sendChatRequest: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
