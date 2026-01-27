import Foundation

// lexicon: 1, id: blue.catbird.mls.getKeyPackageHistory

public enum BlueCatbirdMlsGetKeyPackageHistory {
    public static let typeIdentifier = "blue.catbird.mls.getKeyPackageHistory"

    public struct KeyPackageHistoryEntry: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.getKeyPackageHistory#keyPackageHistoryEntry"
        public let packageId: String
        public let createdAt: ATProtocolDate
        public let consumedAt: ATProtocolDate?
        public let consumedForConvo: String?
        public let consumedForConvoName: String?
        public let consumedByDevice: String?
        public let deviceId: String?
        public let cipherSuite: String

        public init(
            packageId: String, createdAt: ATProtocolDate, consumedAt: ATProtocolDate?, consumedForConvo: String?, consumedForConvoName: String?, consumedByDevice: String?, deviceId: String?, cipherSuite: String
        ) {
            self.packageId = packageId
            self.createdAt = createdAt
            self.consumedAt = consumedAt
            self.consumedForConvo = consumedForConvo
            self.consumedForConvoName = consumedForConvoName
            self.consumedByDevice = consumedByDevice
            self.deviceId = deviceId
            self.cipherSuite = cipherSuite
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                packageId = try container.decode(String.self, forKey: .packageId)
            } catch {
                LogManager.logError("Decoding error for required property 'packageId': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
            do {
                consumedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .consumedAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'consumedAt': \(error)")
                throw error
            }
            do {
                consumedForConvo = try container.decodeIfPresent(String.self, forKey: .consumedForConvo)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'consumedForConvo': \(error)")
                throw error
            }
            do {
                consumedForConvoName = try container.decodeIfPresent(String.self, forKey: .consumedForConvoName)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'consumedForConvoName': \(error)")
                throw error
            }
            do {
                consumedByDevice = try container.decodeIfPresent(String.self, forKey: .consumedByDevice)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'consumedByDevice': \(error)")
                throw error
            }
            do {
                deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'deviceId': \(error)")
                throw error
            }
            do {
                cipherSuite = try container.decode(String.self, forKey: .cipherSuite)
            } catch {
                LogManager.logError("Decoding error for required property 'cipherSuite': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(packageId, forKey: .packageId)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(consumedAt, forKey: .consumedAt)
            try container.encodeIfPresent(consumedForConvo, forKey: .consumedForConvo)
            try container.encodeIfPresent(consumedForConvoName, forKey: .consumedForConvoName)
            try container.encodeIfPresent(consumedByDevice, forKey: .consumedByDevice)
            try container.encodeIfPresent(deviceId, forKey: .deviceId)
            try container.encode(cipherSuite, forKey: .cipherSuite)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(packageId)
            hasher.combine(createdAt)
            if let value = consumedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = consumedForConvo {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = consumedForConvoName {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = consumedByDevice {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = deviceId {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(cipherSuite)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if packageId != other.packageId {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if consumedAt != other.consumedAt {
                return false
            }
            if consumedForConvo != other.consumedForConvo {
                return false
            }
            if consumedForConvoName != other.consumedForConvoName {
                return false
            }
            if consumedByDevice != other.consumedByDevice {
                return false
            }
            if deviceId != other.deviceId {
                return false
            }
            if cipherSuite != other.cipherSuite {
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
            let packageIdValue = try packageId.toCBORValue()
            map = map.adding(key: "packageId", value: packageIdValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = consumedAt {
                let consumedAtValue = try value.toCBORValue()
                map = map.adding(key: "consumedAt", value: consumedAtValue)
            }
            if let value = consumedForConvo {
                let consumedForConvoValue = try value.toCBORValue()
                map = map.adding(key: "consumedForConvo", value: consumedForConvoValue)
            }
            if let value = consumedForConvoName {
                let consumedForConvoNameValue = try value.toCBORValue()
                map = map.adding(key: "consumedForConvoName", value: consumedForConvoNameValue)
            }
            if let value = consumedByDevice {
                let consumedByDeviceValue = try value.toCBORValue()
                map = map.adding(key: "consumedByDevice", value: consumedByDeviceValue)
            }
            if let value = deviceId {
                let deviceIdValue = try value.toCBORValue()
                map = map.adding(key: "deviceId", value: deviceIdValue)
            }
            let cipherSuiteValue = try cipherSuite.toCBORValue()
            map = map.adding(key: "cipherSuite", value: cipherSuiteValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case packageId
            case createdAt
            case consumedAt
            case consumedForConvo
            case consumedForConvoName
            case consumedByDevice
            case deviceId
            case cipherSuite
        }
    }

    public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?

        public init(
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let history: [KeyPackageHistoryEntry]

        public let cursor: String?

        /// Standard public initializer
        public init(
            history: [KeyPackageHistoryEntry],

            cursor: String? = nil

        ) {
            self.history = history

            self.cursor = cursor
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            history = try container.decode([KeyPackageHistoryEntry].self, forKey: .history)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(history, forKey: .history)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let historyValue = try history.toCBORValue()
            map = map.adding(key: "history", value: historyValue)

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case history
            case cursor
        }
    }
}

public extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - getKeyPackageHistory

    /// Get key package consumption history for the authenticated user
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getKeyPackageHistory(input: BlueCatbirdMlsGetKeyPackageHistory.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetKeyPackageHistory.Output?) {
        let endpoint = "blue.catbird.mls.getKeyPackageHistory"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getKeyPackageHistory")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetKeyPackageHistory.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getKeyPackageHistory: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
