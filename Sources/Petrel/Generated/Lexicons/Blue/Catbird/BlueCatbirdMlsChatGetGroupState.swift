import Foundation

// lexicon: 1, id: blue.catbird.mlsChat.getGroupState

public enum BlueCatbirdMlsChatGetGroupState {
    public static let typeIdentifier = "blue.catbird.mlsChat.getGroupState"
    public struct Parameters: Parametrizable {
        public let convoId: String
        public let include: String?
        public let keyPackageHashes: [String]?
        public let deviceId: String?

        public init(
            convoId: String,
            include: String? = nil,
            keyPackageHashes: [String]? = nil,
            deviceId: String? = nil
        ) {
            self.convoId = convoId
            self.include = include
            self.keyPackageHashes = keyPackageHashes
            self.deviceId = deviceId
        }
    }

    public struct Output: ATProtocolCodable {
        public let groupInfo: Bytes?

        public let epoch: Int?

        public let welcome: Bytes?

        public let expiresAt: ATProtocolDate?

        /// Standard public initializer
        public init(
            groupInfo: Bytes? = nil,

            epoch: Int? = nil,

            welcome: Bytes? = nil,

            expiresAt: ATProtocolDate? = nil

        ) {
            self.groupInfo = groupInfo

            self.epoch = epoch

            self.welcome = welcome

            self.expiresAt = expiresAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            do {
                groupInfo = try container.decodeIfPresent(Bytes.self, forKey: .groupInfo)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'groupInfo' — degrading to nil: \(error)")
                groupInfo = nil
            }

            do {
                epoch = try container.decodeIfPresent(Int.self, forKey: .epoch)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'epoch' — degrading to nil: \(error)")
                epoch = nil
            }

            do {
                welcome = try container.decodeIfPresent(Bytes.self, forKey: .welcome)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'welcome' — degrading to nil: \(error)")
                welcome = nil
            }

            do {
                expiresAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .expiresAt)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'expiresAt' — degrading to nil: \(error)")
                expiresAt = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(groupInfo, forKey: .groupInfo)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(epoch, forKey: .epoch)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(welcome, forKey: .welcome)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = groupInfo {
                // Encode optional property even if it's an empty array for CBOR
                let groupInfoValue = try value.toCBORValue()
                map = map.adding(key: "groupInfo", value: groupInfoValue)
            }

            if let value = epoch {
                // Encode optional property even if it's an empty array for CBOR
                let epochValue = try value.toCBORValue()
                map = map.adding(key: "epoch", value: epochValue)
            }

            if let value = welcome {
                // Encode optional property even if it's an empty array for CBOR
                let welcomeValue = try value.toCBORValue()
                map = map.adding(key: "welcome", value: welcomeValue)
            }

            if let value = expiresAt {
                // Encode optional property even if it's an empty array for CBOR
                let expiresAtValue = try value.toCBORValue()
                map = map.adding(key: "expiresAt", value: expiresAtValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case groupInfo
            case epoch
            case welcome
            case expiresAt
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case notFound = "NotFound.Conversation not found"
        case unauthorized = "Unauthorized.Not a current or past member"
        case groupInfoUnavailable = "GroupInfoUnavailable.GroupInfo not yet generated for this conversation"
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

public extension ATProtoClient.Blue.Catbird.MlsChat {
    // MARK: - getGroupState

    /// Retrieve group state including GroupInfo, epoch, and welcome data (consolidates getGroupInfo + getEpoch + validateWelcome) Fetch MLS group state for a conversation. The 'include' parameter selects which state components to return, reducing multiple round-trips to a single call.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getGroupState(input: BlueCatbirdMlsChatGetGroupState.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatGetGroupState.Output?) {
        let endpoint = "blue.catbird.mlsChat.getGroupState"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.getGroupState")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        // Only validate Content-Type and decode on success. Error responses
        // (4xx/5xx) may have missing or different Content-Type headers and
        // are handled via the status code / structured error parser below.
        if (200 ... 299).contains(responseCode) {
            guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
                throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
            }

            if !contentType.lowercased().contains("application/json") {
                throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
            }

            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(BlueCatbirdMlsChatGetGroupState.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.getGroupState: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
