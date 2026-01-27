import Foundation

// lexicon: 1, id: blue.catbird.mls.getPendingDeviceAdditions

public enum BlueCatbirdMlsGetPendingDeviceAdditions {
    public static let typeIdentifier = "blue.catbird.mls.getPendingDeviceAdditions"

    public struct PendingDeviceAddition: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.getPendingDeviceAdditions#pendingDeviceAddition"
        public let id: String
        public let convoId: String
        public let userDid: DID
        public let deviceId: String
        public let deviceName: String?
        public let deviceCredentialDid: String
        public let status: String
        public let claimedBy: DID?
        public let createdAt: ATProtocolDate

        /// Standard initializer
        public init(
            id: String, convoId: String, userDid: DID, deviceId: String, deviceName: String?, deviceCredentialDid: String, status: String, claimedBy: DID?, createdAt: ATProtocolDate
        ) {
            self.id = id
            self.convoId = convoId
            self.userDid = userDid
            self.deviceId = deviceId
            self.deviceName = deviceName
            self.deviceCredentialDid = deviceCredentialDid
            self.status = status
            self.claimedBy = claimedBy
            self.createdAt = createdAt
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
                convoId = try container.decode(String.self, forKey: .convoId)

            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")

                throw error
            }
            do {
                userDid = try container.decode(DID.self, forKey: .userDid)

            } catch {
                LogManager.logError("Decoding error for required property 'userDid': \(error)")

                throw error
            }
            do {
                deviceId = try container.decode(String.self, forKey: .deviceId)

            } catch {
                LogManager.logError("Decoding error for required property 'deviceId': \(error)")

                throw error
            }
            do {
                deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'deviceName': \(error)")

                throw error
            }
            do {
                deviceCredentialDid = try container.decode(String.self, forKey: .deviceCredentialDid)

            } catch {
                LogManager.logError("Decoding error for required property 'deviceCredentialDid': \(error)")

                throw error
            }
            do {
                status = try container.decode(String.self, forKey: .status)

            } catch {
                LogManager.logError("Decoding error for required property 'status': \(error)")

                throw error
            }
            do {
                claimedBy = try container.decodeIfPresent(DID.self, forKey: .claimedBy)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'claimedBy': \(error)")

                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(id, forKey: .id)

            try container.encode(convoId, forKey: .convoId)

            try container.encode(userDid, forKey: .userDid)

            try container.encode(deviceId, forKey: .deviceId)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(deviceName, forKey: .deviceName)

            try container.encode(deviceCredentialDid, forKey: .deviceCredentialDid)

            try container.encode(status, forKey: .status)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(claimedBy, forKey: .claimedBy)

            try container.encode(createdAt, forKey: .createdAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(convoId)
            hasher.combine(userDid)
            hasher.combine(deviceId)
            if let value = deviceName {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(deviceCredentialDid)
            hasher.combine(status)
            if let value = claimedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(createdAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if id != other.id {
                return false
            }

            if convoId != other.convoId {
                return false
            }

            if userDid != other.userDid {
                return false
            }

            if deviceId != other.deviceId {
                return false
            }

            if deviceName != other.deviceName {
                return false
            }

            if deviceCredentialDid != other.deviceCredentialDid {
                return false
            }

            if status != other.status {
                return false
            }

            if claimedBy != other.claimedBy {
                return false
            }

            if createdAt != other.createdAt {
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

            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)

            let userDidValue = try userDid.toCBORValue()
            map = map.adding(key: "userDid", value: userDidValue)

            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)

            if let value = deviceName {
                // Encode optional property even if it's an empty array for CBOR

                let deviceNameValue = try value.toCBORValue()
                map = map.adding(key: "deviceName", value: deviceNameValue)
            }

            let deviceCredentialDidValue = try deviceCredentialDid.toCBORValue()
            map = map.adding(key: "deviceCredentialDid", value: deviceCredentialDidValue)

            let statusValue = try status.toCBORValue()
            map = map.adding(key: "status", value: statusValue)

            if let value = claimedBy {
                // Encode optional property even if it's an empty array for CBOR

                let claimedByValue = try value.toCBORValue()
                map = map.adding(key: "claimedBy", value: claimedByValue)
            }

            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case convoId
            case userDid
            case deviceId
            case deviceName
            case deviceCredentialDid
            case status
            case claimedBy
            case createdAt
        }
    }

    public struct Parameters: Parametrizable {
        public let convoIds: [String]?
        public let limit: Int?

        public init(
            convoIds: [String]? = nil,
            limit: Int? = nil
        ) {
            self.convoIds = convoIds
            self.limit = limit
        }
    }

    public struct Output: ATProtocolCodable {
        public let pendingAdditions: [PendingDeviceAddition]

        /// Standard public initializer
        public init(
            pendingAdditions: [PendingDeviceAddition]

        ) {
            self.pendingAdditions = pendingAdditions
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            pendingAdditions = try container.decode([PendingDeviceAddition].self, forKey: .pendingAdditions)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(pendingAdditions, forKey: .pendingAdditions)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let pendingAdditionsValue = try pendingAdditions.toCBORValue()
            map = map.adding(key: "pendingAdditions", value: pendingAdditionsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case pendingAdditions
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
    // MARK: - getPendingDeviceAdditions

    /// Get pending device additions for conversations (polling fallback for SSE) Returns pending device additions for conversations where caller is a member. Used as fallback when SSE events are missed.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getPendingDeviceAdditions(input: BlueCatbirdMlsGetPendingDeviceAdditions.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetPendingDeviceAdditions.Output?) {
        let endpoint = "blue.catbird.mls.getPendingDeviceAdditions"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getPendingDeviceAdditions")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetPendingDeviceAdditions.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getPendingDeviceAdditions: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
