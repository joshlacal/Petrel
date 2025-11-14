import Foundation



// lexicon: 1, id: blue.catbird.mls.registerDevice


public struct BlueCatbirdMlsRegisterDevice { 

    public static let typeIdentifier = "blue.catbird.mls.registerDevice"
public struct Input: ATProtocolCodable {
            public let deviceId: String
            public let deviceName: String
            public let platform: String?
            public let appVersion: String?

            // Standard public initializer
            public init(deviceId: String, deviceName: String, platform: String? = nil, appVersion: String? = nil) {
                self.deviceId = deviceId
                self.deviceName = deviceName
                self.platform = platform
                self.appVersion = appVersion
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.deviceId = try container.decode(String.self, forKey: .deviceId)
                
                
                self.deviceName = try container.decode(String.self, forKey: .deviceName)
                
                
                self.platform = try container.decodeIfPresent(String.self, forKey: .platform)
                
                
                self.appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(deviceId, forKey: .deviceId)
                
                
                try container.encode(deviceName, forKey: .deviceName)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(platform, forKey: .platform)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(appVersion, forKey: .appVersion)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case deviceId
                case deviceName
                case platform
                case appVersion
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let deviceIdValue = try deviceId.toCBORValue()
                map = map.adding(key: "deviceId", value: deviceIdValue)
                
                
                
                let deviceNameValue = try deviceName.toCBORValue()
                map = map.adding(key: "deviceName", value: deviceNameValue)
                
                
                
                if let value = platform {
                    // Encode optional property even if it's an empty array for CBOR
                    let platformValue = try value.toCBORValue()
                    map = map.adding(key: "platform", value: platformValue)
                }
                
                
                
                if let value = appVersion {
                    // Encode optional property even if it's an empty array for CBOR
                    let appVersionValue = try value.toCBORValue()
                    map = map.adding(key: "appVersion", value: appVersionValue)
                }
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let deviceId: String
        
        public let credentialDid: String
        
        public let userDid: String
        
        public let registeredAt: ATProtocolDate
        
        public let isNewDevice: Bool?
        
        
        
        // Standard public initializer
        public init(
            
            
            deviceId: String,
            
            credentialDid: String,
            
            userDid: String,
            
            registeredAt: ATProtocolDate,
            
            isNewDevice: Bool? = nil
            
            
        ) {
            
            
            self.deviceId = deviceId
            
            self.credentialDid = credentialDid
            
            self.userDid = userDid
            
            self.registeredAt = registeredAt
            
            self.isNewDevice = isNewDevice
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.deviceId = try container.decode(String.self, forKey: .deviceId)
            
            
            self.credentialDid = try container.decode(String.self, forKey: .credentialDid)
            
            
            self.userDid = try container.decode(String.self, forKey: .userDid)
            
            
            self.registeredAt = try container.decode(ATProtocolDate.self, forKey: .registeredAt)
            
            
            self.isNewDevice = try container.decodeIfPresent(Bool.self, forKey: .isNewDevice)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(deviceId, forKey: .deviceId)
            
            
            try container.encode(credentialDid, forKey: .credentialDid)
            
            
            try container.encode(userDid, forKey: .userDid)
            
            
            try container.encode(registeredAt, forKey: .registeredAt)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(isNewDevice, forKey: .isNewDevice)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)
            
            
            
            let credentialDidValue = try credentialDid.toCBORValue()
            map = map.adding(key: "credentialDid", value: credentialDidValue)
            
            
            
            let userDidValue = try userDid.toCBORValue()
            map = map.adding(key: "userDid", value: userDidValue)
            
            
            
            let registeredAtValue = try registeredAt.toCBORValue()
            map = map.adding(key: "registeredAt", value: registeredAtValue)
            
            
            
            if let value = isNewDevice {
                // Encode optional property even if it's an empty array for CBOR
                let isNewDeviceValue = try value.toCBORValue()
                map = map.adding(key: "isNewDevice", value: isNewDeviceValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case deviceId
            case credentialDid
            case userDid
            case registeredAt
            case isNewDevice
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                
                case invalidDeviceId = "InvalidDeviceId"
                
                case invalidDeviceName = "InvalidDeviceName"
                
                case deviceAlreadyRegistered = "DeviceAlreadyRegistered"
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - registerDevice

    /// Register a device for multi-device MLS support. Each device gets a unique device ID and credential (did:plc:user#device-uuid). Required for proper multi-device group conversations.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func registerDevice(
        
        input: BlueCatbirdMlsRegisterDevice.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsRegisterDevice.Output?) {
        let endpoint = "blue.catbird.mls.registerDevice"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.registerDevice")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsRegisterDevice.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.registerDevice: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Try to parse structured error response
            if let atprotoError = ATProtoErrorParser.parse(
                data: responseData,
                statusCode: responseCode,
                errorType: BlueCatbirdMlsRegisterDevice.Error.self
            ) {
                throw atprotoError
            }
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
        
    }
    
}
                           

