import Foundation



// lexicon: 1, id: com.atproto.server.createAppPassword


public struct ComAtprotoServerCreateAppPassword { 

    public static let typeIdentifier = "com.atproto.server.createAppPassword"
        
public struct AppPassword: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.server.createAppPassword#appPassword"
            public let name: String
            public let password: String
            public let createdAt: ATProtocolDate
            public let privileged: Bool?

        // Standard initializer
        public init(
            name: String, password: String, createdAt: ATProtocolDate, privileged: Bool?
        ) {
            
            self.name = name
            self.password = password
            self.createdAt = createdAt
            self.privileged = privileged
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.name = try container.decode(String.self, forKey: .name)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'name': \(error)")
                
                throw error
            }
            do {
                
                
                self.password = try container.decode(String.self, forKey: .password)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'password': \(error)")
                
                throw error
            }
            do {
                
                
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                
                throw error
            }
            do {
                
                
                self.privileged = try container.decodeIfPresent(Bool.self, forKey: .privileged)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'privileged': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(name, forKey: .name)
            
            
            
            
            try container.encode(password, forKey: .password)
            
            
            
            
            try container.encode(createdAt, forKey: .createdAt)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(privileged, forKey: .privileged)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(password)
            hasher.combine(createdAt)
            if let value = privileged {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.name != other.name {
                return false
            }
            
            
            
            
            if self.password != other.password {
                return false
            }
            
            
            
            
            if self.createdAt != other.createdAt {
                return false
            }
            
            
            
            
            if privileged != other.privileged {
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

            
            
            
            
            let nameValue = try name.toCBORValue()
            map = map.adding(key: "name", value: nameValue)
            
            
            
            
            
            
            let passwordValue = try password.toCBORValue()
            map = map.adding(key: "password", value: passwordValue)
            
            
            
            
            
            
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            
            
            
            
            
            if let value = privileged {
                // Encode optional property even if it's an empty array for CBOR
                
                let privilegedValue = try value.toCBORValue()
                map = map.adding(key: "privileged", value: privilegedValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case name
            case password
            case createdAt
            case privileged
        }
    }
public struct Input: ATProtocolCodable {
            public let name: String
            public let privileged: Bool?

            // Standard public initializer
            public init(name: String, privileged: Bool? = nil) {
                self.name = name
                self.privileged = privileged
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.name = try container.decode(String.self, forKey: .name)
                
                
                self.privileged = try container.decodeIfPresent(Bool.self, forKey: .privileged)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(name, forKey: .name)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(privileged, forKey: .privileged)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case name
                case privileged
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let nameValue = try name.toCBORValue()
                map = map.adding(key: "name", value: nameValue)
                
                
                
                if let value = privileged {
                    // Encode optional property even if it's an empty array for CBOR
                    let privilegedValue = try value.toCBORValue()
                    map = map.adding(key: "privileged", value: privilegedValue)
                }
                
                

                return map
            }
        }
    public typealias Output = AppPassword
            
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case accountTakedown = "AccountTakedown."
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

extension ATProtoClient.Com.Atproto.Server {
    // MARK: - createAppPassword

    /// Create an App Password.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func createAppPassword(
        
        input: ComAtprotoServerCreateAppPassword.Input
        
    ) async throws -> (responseCode: Int, data: ComAtprotoServerCreateAppPassword.Output?) {
        let endpoint = "com.atproto.server.createAppPassword"
        
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
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.server.createAppPassword")
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
                let decodedData = try decoder.decode(ComAtprotoServerCreateAppPassword.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.server.createAppPassword: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

