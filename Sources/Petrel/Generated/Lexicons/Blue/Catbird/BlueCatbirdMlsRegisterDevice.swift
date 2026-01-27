import Foundation



// lexicon: 1, id: blue.catbird.mls.registerDevice


public struct BlueCatbirdMlsRegisterDevice { 

    public static let typeIdentifier = "blue.catbird.mls.registerDevice"
        
public struct KeyPackageItem: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.registerDevice#keyPackageItem"
            public let keyPackage: String
            public let cipherSuite: String
            public let expires: ATProtocolDate

        // Standard initializer
        public init(
            keyPackage: String, cipherSuite: String, expires: ATProtocolDate
        ) {
            
            self.keyPackage = keyPackage
            self.cipherSuite = cipherSuite
            self.expires = expires
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.keyPackage = try container.decode(String.self, forKey: .keyPackage)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'keyPackage': \(error)")
                
                throw error
            }
            do {
                
                
                self.cipherSuite = try container.decode(String.self, forKey: .cipherSuite)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'cipherSuite': \(error)")
                
                throw error
            }
            do {
                
                
                self.expires = try container.decode(ATProtocolDate.self, forKey: .expires)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'expires': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(keyPackage, forKey: .keyPackage)
            
            
            
            
            try container.encode(cipherSuite, forKey: .cipherSuite)
            
            
            
            
            try container.encode(expires, forKey: .expires)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(keyPackage)
            hasher.combine(cipherSuite)
            hasher.combine(expires)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.keyPackage != other.keyPackage {
                return false
            }
            
            
            
            
            if self.cipherSuite != other.cipherSuite {
                return false
            }
            
            
            
            
            if self.expires != other.expires {
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

            
            
            
            
            let keyPackageValue = try keyPackage.toCBORValue()
            map = map.adding(key: "keyPackage", value: keyPackageValue)
            
            
            
            
            
            
            let cipherSuiteValue = try cipherSuite.toCBORValue()
            map = map.adding(key: "cipherSuite", value: cipherSuiteValue)
            
            
            
            
            
            
            let expiresValue = try expires.toCBORValue()
            map = map.adding(key: "expires", value: expiresValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case keyPackage
            case cipherSuite
            case expires
        }
    }
        
public struct WelcomeMessage: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.registerDevice#welcomeMessage"
            public let convoId: String
            public let welcome: String

        // Standard initializer
        public init(
            convoId: String, welcome: String
        ) {
            
            self.convoId = convoId
            self.welcome = welcome
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                
                throw error
            }
            do {
                
                
                self.welcome = try container.decode(String.self, forKey: .welcome)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'welcome': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(convoId, forKey: .convoId)
            
            
            
            
            try container.encode(welcome, forKey: .welcome)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(convoId)
            hasher.combine(welcome)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.convoId != other.convoId {
                return false
            }
            
            
            
            
            if self.welcome != other.welcome {
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

            
            
            
            
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            
            
            
            
            
            
            let welcomeValue = try welcome.toCBORValue()
            map = map.adding(key: "welcome", value: welcomeValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case convoId
            case welcome
        }
    }
public struct Input: ATProtocolCodable {
            public let deviceName: String
            public let deviceUUID: String?
            public let keyPackages: [KeyPackageItem]
            public let signaturePublicKey: Bytes

            // Standard public initializer
            public init(deviceName: String, deviceUUID: String? = nil, keyPackages: [KeyPackageItem], signaturePublicKey: Bytes) {
                self.deviceName = deviceName
                self.deviceUUID = deviceUUID
                self.keyPackages = keyPackages
                self.signaturePublicKey = signaturePublicKey
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.deviceName = try container.decode(String.self, forKey: .deviceName)
                
                
                self.deviceUUID = try container.decodeIfPresent(String.self, forKey: .deviceUUID)
                
                
                self.keyPackages = try container.decode([KeyPackageItem].self, forKey: .keyPackages)
                
                
                self.signaturePublicKey = try container.decode(Bytes.self, forKey: .signaturePublicKey)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(deviceName, forKey: .deviceName)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(deviceUUID, forKey: .deviceUUID)
                
                
                try container.encode(keyPackages, forKey: .keyPackages)
                
                
                try container.encode(signaturePublicKey, forKey: .signaturePublicKey)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case deviceName
                case deviceUUID
                case keyPackages
                case signaturePublicKey
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let deviceNameValue = try deviceName.toCBORValue()
                map = map.adding(key: "deviceName", value: deviceNameValue)
                
                
                
                if let value = deviceUUID {
                    // Encode optional property even if it's an empty array for CBOR
                    let deviceUUIDValue = try value.toCBORValue()
                    map = map.adding(key: "deviceUUID", value: deviceUUIDValue)
                }
                
                
                
                let keyPackagesValue = try keyPackages.toCBORValue()
                map = map.adding(key: "keyPackages", value: keyPackagesValue)
                
                
                
                let signaturePublicKeyValue = try signaturePublicKey.toCBORValue()
                map = map.adding(key: "signaturePublicKey", value: signaturePublicKeyValue)
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let deviceId: String
        
        public let mlsDid: String
        
        public let autoJoinedConvos: [String]
        
        public let welcomeMessages: [WelcomeMessage]?
        
        
        
        // Standard public initializer
        public init(
            
            
            deviceId: String,
            
            mlsDid: String,
            
            autoJoinedConvos: [String],
            
            welcomeMessages: [WelcomeMessage]? = nil
            
            
        ) {
            
            
            self.deviceId = deviceId
            
            self.mlsDid = mlsDid
            
            self.autoJoinedConvos = autoJoinedConvos
            
            self.welcomeMessages = welcomeMessages
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.deviceId = try container.decode(String.self, forKey: .deviceId)
            
            
            self.mlsDid = try container.decode(String.self, forKey: .mlsDid)
            
            
            self.autoJoinedConvos = try container.decode([String].self, forKey: .autoJoinedConvos)
            
            
            self.welcomeMessages = try container.decodeIfPresent([WelcomeMessage].self, forKey: .welcomeMessages)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(deviceId, forKey: .deviceId)
            
            
            try container.encode(mlsDid, forKey: .mlsDid)
            
            
            try container.encode(autoJoinedConvos, forKey: .autoJoinedConvos)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(welcomeMessages, forKey: .welcomeMessages)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)
            
            
            
            let mlsDidValue = try mlsDid.toCBORValue()
            map = map.adding(key: "mlsDid", value: mlsDidValue)
            
            
            
            let autoJoinedConvosValue = try autoJoinedConvos.toCBORValue()
            map = map.adding(key: "autoJoinedConvos", value: autoJoinedConvosValue)
            
            
            
            if let value = welcomeMessages {
                // Encode optional property even if it's an empty array for CBOR
                let welcomeMessagesValue = try value.toCBORValue()
                map = map.adding(key: "welcomeMessages", value: welcomeMessagesValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case deviceId
            case mlsDid
            case autoJoinedConvos
            case welcomeMessages
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case invalidDeviceName = "InvalidDeviceName."
                case invalidKeyPackages = "InvalidKeyPackages."
                case invalidSignatureKey = "InvalidSignatureKey."
                case deviceAlreadyRegistered = "DeviceAlreadyRegistered."
                case tooManyDevices = "TooManyDevices."
            public var description: String {
                return self.rawValue
            }

            public var errorName: String {
                // Extract just the error name from the raw value
                let parts = self.rawValue.split(separator: ".")
                return String(parts.first ?? "")
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
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

