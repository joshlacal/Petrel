import Foundation



// lexicon: 1, id: blue.catbird.mls.listDevices


public struct BlueCatbirdMlsListDevices { 

    public static let typeIdentifier = "blue.catbird.mls.listDevices"
        
public struct DeviceInfo: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.listDevices#deviceInfo"
            public let deviceId: String
            public let deviceName: String
            public let deviceUUID: String?
            public let credentialDid: String
            public let lastSeenAt: ATProtocolDate
            public let registeredAt: ATProtocolDate
            public let keyPackageCount: Int

        // Standard initializer
        public init(
            deviceId: String, deviceName: String, deviceUUID: String?, credentialDid: String, lastSeenAt: ATProtocolDate, registeredAt: ATProtocolDate, keyPackageCount: Int
        ) {
            
            self.deviceId = deviceId
            self.deviceName = deviceName
            self.deviceUUID = deviceUUID
            self.credentialDid = credentialDid
            self.lastSeenAt = lastSeenAt
            self.registeredAt = registeredAt
            self.keyPackageCount = keyPackageCount
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.deviceId = try container.decode(String.self, forKey: .deviceId)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'deviceId': \(error)")
                
                throw error
            }
            do {
                
                
                self.deviceName = try container.decode(String.self, forKey: .deviceName)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'deviceName': \(error)")
                
                throw error
            }
            do {
                
                
                self.deviceUUID = try container.decodeIfPresent(String.self, forKey: .deviceUUID)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'deviceUUID': \(error)")
                
                throw error
            }
            do {
                
                
                self.credentialDid = try container.decode(String.self, forKey: .credentialDid)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'credentialDid': \(error)")
                
                throw error
            }
            do {
                
                
                self.lastSeenAt = try container.decode(ATProtocolDate.self, forKey: .lastSeenAt)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'lastSeenAt': \(error)")
                
                throw error
            }
            do {
                
                
                self.registeredAt = try container.decode(ATProtocolDate.self, forKey: .registeredAt)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'registeredAt': \(error)")
                
                throw error
            }
            do {
                
                
                self.keyPackageCount = try container.decode(Int.self, forKey: .keyPackageCount)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'keyPackageCount': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(deviceId, forKey: .deviceId)
            
            
            
            
            try container.encode(deviceName, forKey: .deviceName)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(deviceUUID, forKey: .deviceUUID)
            
            
            
            
            try container.encode(credentialDid, forKey: .credentialDid)
            
            
            
            
            try container.encode(lastSeenAt, forKey: .lastSeenAt)
            
            
            
            
            try container.encode(registeredAt, forKey: .registeredAt)
            
            
            
            
            try container.encode(keyPackageCount, forKey: .keyPackageCount)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(deviceId)
            hasher.combine(deviceName)
            if let value = deviceUUID {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(credentialDid)
            hasher.combine(lastSeenAt)
            hasher.combine(registeredAt)
            hasher.combine(keyPackageCount)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.deviceId != other.deviceId {
                return false
            }
            
            
            
            
            if self.deviceName != other.deviceName {
                return false
            }
            
            
            
            
            if deviceUUID != other.deviceUUID {
                return false
            }
            
            
            
            
            if self.credentialDid != other.credentialDid {
                return false
            }
            
            
            
            
            if self.lastSeenAt != other.lastSeenAt {
                return false
            }
            
            
            
            
            if self.registeredAt != other.registeredAt {
                return false
            }
            
            
            
            
            if self.keyPackageCount != other.keyPackageCount {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)
            
            
            
            
            
            
            let deviceNameValue = try deviceName.toCBORValue()
            map = map.adding(key: "deviceName", value: deviceNameValue)
            
            
            
            
            
            if let value = deviceUUID {
                // Encode optional property even if it's an empty array for CBOR
                
                let deviceUUIDValue = try value.toCBORValue()
                map = map.adding(key: "deviceUUID", value: deviceUUIDValue)
            }
            
            
            
            
            
            
            let credentialDidValue = try credentialDid.toCBORValue()
            map = map.adding(key: "credentialDid", value: credentialDidValue)
            
            
            
            
            
            
            let lastSeenAtValue = try lastSeenAt.toCBORValue()
            map = map.adding(key: "lastSeenAt", value: lastSeenAtValue)
            
            
            
            
            
            
            let registeredAtValue = try registeredAt.toCBORValue()
            map = map.adding(key: "registeredAt", value: registeredAtValue)
            
            
            
            
            
            
            let keyPackageCountValue = try keyPackageCount.toCBORValue()
            map = map.adding(key: "keyPackageCount", value: keyPackageCountValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case deviceId
            case deviceName
            case deviceUUID
            case credentialDid
            case lastSeenAt
            case registeredAt
            case keyPackageCount
        }
    }    
public struct Parameters: Parametrizable {
        
        public init(
            ) {
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let devices: [DeviceInfo]
        
        
        
        // Standard public initializer
        public init(
            
            
            devices: [DeviceInfo]
            
            
        ) {
            
            
            self.devices = devices
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.devices = try container.decode([DeviceInfo].self, forKey: .devices)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(devices, forKey: .devices)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let devicesValue = try devices.toCBORValue()
            map = map.adding(key: "devices", value: devicesValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case devices
        }
        
    }




}



extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - listDevices

    /// List all registered devices for the authenticated user with key package counts and last seen timestamps
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func listDevices(input: BlueCatbirdMlsListDevices.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsListDevices.Output?) {
        let endpoint = "blue.catbird.mls.listDevices"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.listDevices")
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
        if (200...299).contains(responseCode) {
            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(BlueCatbirdMlsListDevices.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.listDevices: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

