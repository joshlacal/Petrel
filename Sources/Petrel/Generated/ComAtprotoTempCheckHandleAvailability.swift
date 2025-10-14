import Foundation



// lexicon: 1, id: com.atproto.temp.checkHandleAvailability


public struct ComAtprotoTempCheckHandleAvailability { 

    public static let typeIdentifier = "com.atproto.temp.checkHandleAvailability"
        
public struct ResultAvailable: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.temp.checkHandleAvailability#resultAvailable"

        // Standard initializer
        public init(
            
        ) {
            
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let _ = decoder  // Acknowledge parameter for empty struct
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            return other is Self  // For empty structs, just check the type
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }
        
public struct ResultUnavailable: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.temp.checkHandleAvailability#resultUnavailable"
            public let suggestions: [Suggestion]

        // Standard initializer
        public init(
            suggestions: [Suggestion]
        ) {
            
            self.suggestions = suggestions
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.suggestions = try container.decode([Suggestion].self, forKey: .suggestions)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'suggestions': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(suggestions, forKey: .suggestions)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(suggestions)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.suggestions != other.suggestions {
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

            
            
            
            
            let suggestionsValue = try suggestions.toCBORValue()
            map = map.adding(key: "suggestions", value: suggestionsValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case suggestions
        }
    }
        
public struct Suggestion: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.temp.checkHandleAvailability#suggestion"
            public let handle: Handle
            public let method: String

        // Standard initializer
        public init(
            handle: Handle, method: String
        ) {
            
            self.handle = handle
            self.method = method
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.handle = try container.decode(Handle.self, forKey: .handle)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'handle': \(error)")
                
                throw error
            }
            do {
                
                
                self.method = try container.decode(String.self, forKey: .method)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'method': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(handle, forKey: .handle)
            
            
            
            
            try container.encode(method, forKey: .method)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(handle)
            hasher.combine(method)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.handle != other.handle {
                return false
            }
            
            
            
            
            if self.method != other.method {
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

            
            
            
            
            let handleValue = try handle.toCBORValue()
            map = map.adding(key: "handle", value: handleValue)
            
            
            
            
            
            
            let methodValue = try method.toCBORValue()
            map = map.adding(key: "method", value: methodValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case handle
            case method
        }
    }    
public struct Parameters: Parametrizable {
        public let handle: Handle
        public let email: String?
        public let birthDate: ATProtocolDate?
        
        public init(
            handle: Handle, 
            email: String? = nil, 
            birthDate: ATProtocolDate? = nil
            ) {
            self.handle = handle
            self.email = email
            self.birthDate = birthDate
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let handle: Handle
        
        public let result: OutputResultUnion
        
        
        
        // Standard public initializer
        public init(
            
            
            handle: Handle,
            
            result: OutputResultUnion
            
            
        ) {
            
            
            self.handle = handle
            
            self.result = result
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.handle = try container.decode(Handle.self, forKey: .handle)
            
            
            self.result = try container.decode(OutputResultUnion.self, forKey: .result)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(handle, forKey: .handle)
            
            
            try container.encode(result, forKey: .result)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let handleValue = try handle.toCBORValue()
            map = map.adding(key: "handle", value: handleValue)
            
            
            
            let resultValue = try result.toCBORValue()
            map = map.adding(key: "result", value: resultValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case handle
            case result
        }
        
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case invalidEmail = "InvalidEmail.An invalid email was provided."
            public var description: String {
                return self.rawValue
            }
        }





public enum OutputResultUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case comAtprotoTempCheckHandleAvailabilityResultAvailable(ComAtprotoTempCheckHandleAvailability.ResultAvailable)
    case comAtprotoTempCheckHandleAvailabilityResultUnavailable(ComAtprotoTempCheckHandleAvailability.ResultUnavailable)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: ComAtprotoTempCheckHandleAvailability.ResultAvailable) {
        self = .comAtprotoTempCheckHandleAvailabilityResultAvailable(value)
    }
    public init(_ value: ComAtprotoTempCheckHandleAvailability.ResultUnavailable) {
        self = .comAtprotoTempCheckHandleAvailabilityResultUnavailable(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)
        

        switch typeValue {
        case "com.atproto.temp.checkHandleAvailability#resultAvailable":
            let value = try ComAtprotoTempCheckHandleAvailability.ResultAvailable(from: decoder)
            self = .comAtprotoTempCheckHandleAvailabilityResultAvailable(value)
        case "com.atproto.temp.checkHandleAvailability#resultUnavailable":
            let value = try ComAtprotoTempCheckHandleAvailability.ResultUnavailable(from: decoder)
            self = .comAtprotoTempCheckHandleAvailabilityResultUnavailable(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .comAtprotoTempCheckHandleAvailabilityResultAvailable(let value):
            try container.encode("com.atproto.temp.checkHandleAvailability#resultAvailable", forKey: .type)
            try value.encode(to: encoder)
        case .comAtprotoTempCheckHandleAvailabilityResultUnavailable(let value):
            try container.encode("com.atproto.temp.checkHandleAvailability#resultUnavailable", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .comAtprotoTempCheckHandleAvailabilityResultAvailable(let value):
            hasher.combine("com.atproto.temp.checkHandleAvailability#resultAvailable")
            hasher.combine(value)
        case .comAtprotoTempCheckHandleAvailabilityResultUnavailable(let value):
            hasher.combine("com.atproto.temp.checkHandleAvailability#resultUnavailable")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: OutputResultUnion, rhs: OutputResultUnion) -> Bool {
        switch (lhs, rhs) {
        case (.comAtprotoTempCheckHandleAvailabilityResultAvailable(let lhsValue),
              .comAtprotoTempCheckHandleAvailabilityResultAvailable(let rhsValue)):
            return lhsValue == rhsValue
        case (.comAtprotoTempCheckHandleAvailabilityResultUnavailable(let lhsValue),
              .comAtprotoTempCheckHandleAvailabilityResultUnavailable(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? OutputResultUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .comAtprotoTempCheckHandleAvailabilityResultAvailable(let value):
            map = map.adding(key: "$type", value: "com.atproto.temp.checkHandleAvailability#resultAvailable")
            
            let valueDict = try value.toCBORValue()

            // If the value is already an OrderedCBORMap, merge its entries
            if let orderedMap = valueDict as? OrderedCBORMap {
                for (key, value) in orderedMap.entries where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            } else if let dict = valueDict as? [String: Any] {
                // Otherwise add each key-value pair from the dictionary
                for (key, value) in dict where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            }
            return map
        case .comAtprotoTempCheckHandleAvailabilityResultUnavailable(let value):
            map = map.adding(key: "$type", value: "com.atproto.temp.checkHandleAvailability#resultUnavailable")
            
            let valueDict = try value.toCBORValue()

            // If the value is already an OrderedCBORMap, merge its entries
            if let orderedMap = valueDict as? OrderedCBORMap {
                for (key, value) in orderedMap.entries where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            } else if let dict = valueDict as? [String: Any] {
                // Otherwise add each key-value pair from the dictionary
                for (key, value) in dict where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            }
            return map
        case .unexpected(let container):
            return try container.toCBORValue()
        
        }
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .comAtprotoTempCheckHandleAvailabilityResultAvailable(let value):
            return value.hasPendingData
        case .comAtprotoTempCheckHandleAvailabilityResultUnavailable(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .comAtprotoTempCheckHandleAvailabilityResultAvailable(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoTempCheckHandleAvailabilityResultAvailable(value)
        case .comAtprotoTempCheckHandleAvailabilityResultUnavailable(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoTempCheckHandleAvailabilityResultUnavailable(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}


}


extension ATProtoClient.Com.Atproto.Temp {
    // MARK: - checkHandleAvailability

    /// Checks whether the provided handle is available. If the handle is not available, available suggestions will be returned. Optional inputs will be used to generate suggestions.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func checkHandleAvailability(input: ComAtprotoTempCheckHandleAvailability.Parameters) async throws -> (responseCode: Int, data: ComAtprotoTempCheckHandleAvailability.Output?) {
        let endpoint = "com.atproto.temp.checkHandleAvailability"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.temp.checkHandleAvailability")
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
                let decodedData = try decoder.decode(ComAtprotoTempCheckHandleAvailability.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.temp.checkHandleAvailability: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           
