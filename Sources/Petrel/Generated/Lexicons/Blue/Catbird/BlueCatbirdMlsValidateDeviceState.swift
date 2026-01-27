import Foundation



// lexicon: 1, id: blue.catbird.mls.validateDeviceState


public struct BlueCatbirdMlsValidateDeviceState { 

    public static let typeIdentifier = "blue.catbird.mls.validateDeviceState"
        
public struct KeyPackageInventory: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.validateDeviceState#keyPackageInventory"
            public let available: Int
            public let target: Int
            public let needsReplenishment: Bool
            public let perDeviceCount: Int?

        // Standard initializer
        public init(
            available: Int, target: Int, needsReplenishment: Bool, perDeviceCount: Int?
        ) {
            
            self.available = available
            self.target = target
            self.needsReplenishment = needsReplenishment
            self.perDeviceCount = perDeviceCount
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.available = try container.decode(Int.self, forKey: .available)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'available': \(error)")
                
                throw error
            }
            do {
                
                
                self.target = try container.decode(Int.self, forKey: .target)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'target': \(error)")
                
                throw error
            }
            do {
                
                
                self.needsReplenishment = try container.decode(Bool.self, forKey: .needsReplenishment)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'needsReplenishment': \(error)")
                
                throw error
            }
            do {
                
                
                self.perDeviceCount = try container.decodeIfPresent(Int.self, forKey: .perDeviceCount)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'perDeviceCount': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(available, forKey: .available)
            
            
            
            
            try container.encode(target, forKey: .target)
            
            
            
            
            try container.encode(needsReplenishment, forKey: .needsReplenishment)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(perDeviceCount, forKey: .perDeviceCount)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(available)
            hasher.combine(target)
            hasher.combine(needsReplenishment)
            if let value = perDeviceCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.available != other.available {
                return false
            }
            
            
            
            
            if self.target != other.target {
                return false
            }
            
            
            
            
            if self.needsReplenishment != other.needsReplenishment {
                return false
            }
            
            
            
            
            if perDeviceCount != other.perDeviceCount {
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

            
            
            
            
            let availableValue = try available.toCBORValue()
            map = map.adding(key: "available", value: availableValue)
            
            
            
            
            
            
            let targetValue = try target.toCBORValue()
            map = map.adding(key: "target", value: targetValue)
            
            
            
            
            
            
            let needsReplenishmentValue = try needsReplenishment.toCBORValue()
            map = map.adding(key: "needsReplenishment", value: needsReplenishmentValue)
            
            
            
            
            
            if let value = perDeviceCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let perDeviceCountValue = try value.toCBORValue()
                map = map.adding(key: "perDeviceCount", value: perDeviceCountValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case available
            case target
            case needsReplenishment
            case perDeviceCount
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
        
        
        public let isValid: Bool
        
        public let issues: [String]
        
        public let recommendations: [String]
        
        public let expectedConvos: Int?
        
        public let actualConvos: Int?
        
        public let keyPackageInventory: KeyPackageInventory?
        
        public let pendingRejoinRequests: [String]?
        
        
        
        // Standard public initializer
        public init(
            
            
            isValid: Bool,
            
            issues: [String],
            
            recommendations: [String],
            
            expectedConvos: Int? = nil,
            
            actualConvos: Int? = nil,
            
            keyPackageInventory: KeyPackageInventory? = nil,
            
            pendingRejoinRequests: [String]? = nil
            
            
        ) {
            
            
            self.isValid = isValid
            
            self.issues = issues
            
            self.recommendations = recommendations
            
            self.expectedConvos = expectedConvos
            
            self.actualConvos = actualConvos
            
            self.keyPackageInventory = keyPackageInventory
            
            self.pendingRejoinRequests = pendingRejoinRequests
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.isValid = try container.decode(Bool.self, forKey: .isValid)
            
            
            self.issues = try container.decode([String].self, forKey: .issues)
            
            
            self.recommendations = try container.decode([String].self, forKey: .recommendations)
            
            
            self.expectedConvos = try container.decodeIfPresent(Int.self, forKey: .expectedConvos)
            
            
            self.actualConvos = try container.decodeIfPresent(Int.self, forKey: .actualConvos)
            
            
            self.keyPackageInventory = try container.decodeIfPresent(KeyPackageInventory.self, forKey: .keyPackageInventory)
            
            
            self.pendingRejoinRequests = try container.decodeIfPresent([String].self, forKey: .pendingRejoinRequests)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(isValid, forKey: .isValid)
            
            
            try container.encode(issues, forKey: .issues)
            
            
            try container.encode(recommendations, forKey: .recommendations)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(expectedConvos, forKey: .expectedConvos)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(actualConvos, forKey: .actualConvos)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(keyPackageInventory, forKey: .keyPackageInventory)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(pendingRejoinRequests, forKey: .pendingRejoinRequests)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let isValidValue = try isValid.toCBORValue()
            map = map.adding(key: "isValid", value: isValidValue)
            
            
            
            let issuesValue = try issues.toCBORValue()
            map = map.adding(key: "issues", value: issuesValue)
            
            
            
            let recommendationsValue = try recommendations.toCBORValue()
            map = map.adding(key: "recommendations", value: recommendationsValue)
            
            
            
            if let value = expectedConvos {
                // Encode optional property even if it's an empty array for CBOR
                let expectedConvosValue = try value.toCBORValue()
                map = map.adding(key: "expectedConvos", value: expectedConvosValue)
            }
            
            
            
            if let value = actualConvos {
                // Encode optional property even if it's an empty array for CBOR
                let actualConvosValue = try value.toCBORValue()
                map = map.adding(key: "actualConvos", value: actualConvosValue)
            }
            
            
            
            if let value = keyPackageInventory {
                // Encode optional property even if it's an empty array for CBOR
                let keyPackageInventoryValue = try value.toCBORValue()
                map = map.adding(key: "keyPackageInventory", value: keyPackageInventoryValue)
            }
            
            
            
            if let value = pendingRejoinRequests {
                // Encode optional property even if it's an empty array for CBOR
                let pendingRejoinRequestsValue = try value.toCBORValue()
                map = map.adding(key: "pendingRejoinRequests", value: pendingRejoinRequestsValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case isValid
            case issues
            case recommendations
            case expectedConvos
            case actualConvos
            case keyPackageInventory
            case pendingRejoinRequests
        }
        
    }




}



extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - validateDeviceState

    /// Validate device state and sync status for the authenticated user
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func validateDeviceState(input: BlueCatbirdMlsValidateDeviceState.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsValidateDeviceState.Output?) {
        let endpoint = "blue.catbird.mls.validateDeviceState"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.validateDeviceState")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsValidateDeviceState.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.validateDeviceState: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

