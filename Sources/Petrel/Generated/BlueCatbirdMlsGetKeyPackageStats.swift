import Foundation



// lexicon: 1, id: blue.catbird.mls.getKeyPackageStats


public struct BlueCatbirdMlsGetKeyPackageStats { 

    public static let typeIdentifier = "blue.catbird.mls.getKeyPackageStats"
        
public struct CipherSuiteStats: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.getKeyPackageStats#cipherSuiteStats"
            public let cipherSuite: String
            public let available: Int
            public let consumed: Int?

        // Standard initializer
        public init(
            cipherSuite: String, available: Int, consumed: Int?
        ) {
            
            self.cipherSuite = cipherSuite
            self.available = available
            self.consumed = consumed
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.cipherSuite = try container.decode(String.self, forKey: .cipherSuite)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'cipherSuite': \(error)")
                
                throw error
            }
            do {
                
                
                self.available = try container.decode(Int.self, forKey: .available)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'available': \(error)")
                
                throw error
            }
            do {
                
                
                self.consumed = try container.decodeIfPresent(Int.self, forKey: .consumed)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'consumed': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(cipherSuite, forKey: .cipherSuite)
            
            
            
            
            try container.encode(available, forKey: .available)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(consumed, forKey: .consumed)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cipherSuite)
            hasher.combine(available)
            if let value = consumed {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.cipherSuite != other.cipherSuite {
                return false
            }
            
            
            
            
            if self.available != other.available {
                return false
            }
            
            
            
            
            if consumed != other.consumed {
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

            
            
            
            
            let cipherSuiteValue = try cipherSuite.toCBORValue()
            map = map.adding(key: "cipherSuite", value: cipherSuiteValue)
            
            
            
            
            
            
            let availableValue = try available.toCBORValue()
            map = map.adding(key: "available", value: availableValue)
            
            
            
            
            
            if let value = consumed {
                // Encode optional property even if it's an empty array for CBOR
                
                let consumedValue = try value.toCBORValue()
                map = map.adding(key: "consumed", value: consumedValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cipherSuite
            case available
            case consumed
        }
    }    
public struct Parameters: Parametrizable {
        public let did: DID?
        public let cipherSuite: String?
        
        public init(
            did: DID? = nil, 
            cipherSuite: String? = nil
            ) {
            self.did = did
            self.cipherSuite = cipherSuite
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let available: Int
        
        public let threshold: Int
        
        public let needsReplenish: Bool
        
        public let total: Int
        
        public let consumed: Int
        
        public let consumedLast24h: Int
        
        public let consumedLast7d: Int
        
        public let averageDailyConsumption: Int
        
        public let predictedDepletionDays: Int?
        
        public let oldestExpiresIn: String?
        
        public let byCipherSuite: [CipherSuiteStats]?
        
        
        
        // Standard public initializer
        public init(
            
            
            available: Int,
            
            threshold: Int,
            
            needsReplenish: Bool,
            
            total: Int,
            
            consumed: Int,
            
            consumedLast24h: Int,
            
            consumedLast7d: Int,
            
            averageDailyConsumption: Int,
            
            predictedDepletionDays: Int? = nil,
            
            oldestExpiresIn: String? = nil,
            
            byCipherSuite: [CipherSuiteStats]? = nil
            
            
        ) {
            
            
            self.available = available
            
            self.threshold = threshold
            
            self.needsReplenish = needsReplenish
            
            self.total = total
            
            self.consumed = consumed
            
            self.consumedLast24h = consumedLast24h
            
            self.consumedLast7d = consumedLast7d
            
            self.averageDailyConsumption = averageDailyConsumption
            
            self.predictedDepletionDays = predictedDepletionDays
            
            self.oldestExpiresIn = oldestExpiresIn
            
            self.byCipherSuite = byCipherSuite
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.available = try container.decode(Int.self, forKey: .available)
            
            
            self.threshold = try container.decode(Int.self, forKey: .threshold)
            
            
            self.needsReplenish = try container.decode(Bool.self, forKey: .needsReplenish)
            
            
            self.total = try container.decode(Int.self, forKey: .total)
            
            
            self.consumed = try container.decode(Int.self, forKey: .consumed)
            
            
            self.consumedLast24h = try container.decode(Int.self, forKey: .consumedLast24h)
            
            
            self.consumedLast7d = try container.decode(Int.self, forKey: .consumedLast7d)
            
            
            self.averageDailyConsumption = try container.decode(Int.self, forKey: .averageDailyConsumption)
            
            
            self.predictedDepletionDays = try container.decodeIfPresent(Int.self, forKey: .predictedDepletionDays)
            
            
            self.oldestExpiresIn = try container.decodeIfPresent(String.self, forKey: .oldestExpiresIn)
            
            
            self.byCipherSuite = try container.decodeIfPresent([CipherSuiteStats].self, forKey: .byCipherSuite)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(available, forKey: .available)
            
            
            try container.encode(threshold, forKey: .threshold)
            
            
            try container.encode(needsReplenish, forKey: .needsReplenish)
            
            
            try container.encode(total, forKey: .total)
            
            
            try container.encode(consumed, forKey: .consumed)
            
            
            try container.encode(consumedLast24h, forKey: .consumedLast24h)
            
            
            try container.encode(consumedLast7d, forKey: .consumedLast7d)
            
            
            try container.encode(averageDailyConsumption, forKey: .averageDailyConsumption)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(predictedDepletionDays, forKey: .predictedDepletionDays)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(oldestExpiresIn, forKey: .oldestExpiresIn)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(byCipherSuite, forKey: .byCipherSuite)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let availableValue = try available.toCBORValue()
            map = map.adding(key: "available", value: availableValue)
            
            
            
            let thresholdValue = try threshold.toCBORValue()
            map = map.adding(key: "threshold", value: thresholdValue)
            
            
            
            let needsReplenishValue = try needsReplenish.toCBORValue()
            map = map.adding(key: "needsReplenish", value: needsReplenishValue)
            
            
            
            let totalValue = try total.toCBORValue()
            map = map.adding(key: "total", value: totalValue)
            
            
            
            let consumedValue = try consumed.toCBORValue()
            map = map.adding(key: "consumed", value: consumedValue)
            
            
            
            let consumedLast24hValue = try consumedLast24h.toCBORValue()
            map = map.adding(key: "consumedLast24h", value: consumedLast24hValue)
            
            
            
            let consumedLast7dValue = try consumedLast7d.toCBORValue()
            map = map.adding(key: "consumedLast7d", value: consumedLast7dValue)
            
            
            
            let averageDailyConsumptionValue = try averageDailyConsumption.toCBORValue()
            map = map.adding(key: "averageDailyConsumption", value: averageDailyConsumptionValue)
            
            
            
            if let value = predictedDepletionDays {
                // Encode optional property even if it's an empty array for CBOR
                let predictedDepletionDaysValue = try value.toCBORValue()
                map = map.adding(key: "predictedDepletionDays", value: predictedDepletionDaysValue)
            }
            
            
            
            if let value = oldestExpiresIn {
                // Encode optional property even if it's an empty array for CBOR
                let oldestExpiresInValue = try value.toCBORValue()
                map = map.adding(key: "oldestExpiresIn", value: oldestExpiresInValue)
            }
            
            
            
            if let value = byCipherSuite {
                // Encode optional property even if it's an empty array for CBOR
                let byCipherSuiteValue = try value.toCBORValue()
                map = map.adding(key: "byCipherSuite", value: byCipherSuiteValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case available
            case threshold
            case needsReplenish
            case total
            case consumed
            case consumedLast24h
            case consumedLast7d
            case averageDailyConsumption
            case predictedDepletionDays
            case oldestExpiresIn
            case byCipherSuite
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                /// The provided DID is invalid
                case invalidDid = "InvalidDid"
            public var description: String {
                return self.rawValue
            }
        }



}



extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - getKeyPackageStats

    /// Get key package inventory statistics for the authenticated user to determine when replenishment is needed
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getKeyPackageStats(input: BlueCatbirdMlsGetKeyPackageStats.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetKeyPackageStats.Output?) {
        let endpoint = "blue.catbird.mls.getKeyPackageStats"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getKeyPackageStats")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetKeyPackageStats.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getKeyPackageStats: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Try to parse structured error response
            if let atprotoError = ATProtoErrorParser.parse(
                data: responseData,
                statusCode: responseCode,
                errorType: BlueCatbirdMlsGetKeyPackageStats.Error.self
            ) {
                throw atprotoError
            }
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

