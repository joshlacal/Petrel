import Foundation



// lexicon: 1, id: blue.catbird.mls.getKeyPackageStatus


public struct BlueCatbirdMlsGetKeyPackageStatus { 

    public static let typeIdentifier = "blue.catbird.mls.getKeyPackageStatus"
        
public struct ConsumedPackageView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.getKeyPackageStatus#consumedPackageView"
            public let keyPackageHash: String
            public let usedInGroup: String?
            public let consumedAt: ATProtocolDate
            public let cipherSuite: String?

        public init(
            keyPackageHash: String, usedInGroup: String?, consumedAt: ATProtocolDate, cipherSuite: String?
        ) {
            self.keyPackageHash = keyPackageHash
            self.usedInGroup = usedInGroup
            self.consumedAt = consumedAt
            self.cipherSuite = cipherSuite
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.keyPackageHash = try container.decode(String.self, forKey: .keyPackageHash)
            } catch {
                LogManager.logError("Decoding error for required property 'keyPackageHash': \(error)")
                throw error
            }
            do {
                self.usedInGroup = try container.decodeIfPresent(String.self, forKey: .usedInGroup)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'usedInGroup': \(error)")
                throw error
            }
            do {
                self.consumedAt = try container.decode(ATProtocolDate.self, forKey: .consumedAt)
            } catch {
                LogManager.logError("Decoding error for required property 'consumedAt': \(error)")
                throw error
            }
            do {
                self.cipherSuite = try container.decodeIfPresent(String.self, forKey: .cipherSuite)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'cipherSuite': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(keyPackageHash, forKey: .keyPackageHash)
            try container.encodeIfPresent(usedInGroup, forKey: .usedInGroup)
            try container.encode(consumedAt, forKey: .consumedAt)
            try container.encodeIfPresent(cipherSuite, forKey: .cipherSuite)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(keyPackageHash)
            if let value = usedInGroup {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(consumedAt)
            if let value = cipherSuite {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if keyPackageHash != other.keyPackageHash {
                return false
            }
            if usedInGroup != other.usedInGroup {
                return false
            }
            if consumedAt != other.consumedAt {
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
            let keyPackageHashValue = try keyPackageHash.toCBORValue()
            map = map.adding(key: "keyPackageHash", value: keyPackageHashValue)
            if let value = usedInGroup {
                let usedInGroupValue = try value.toCBORValue()
                map = map.adding(key: "usedInGroup", value: usedInGroupValue)
            }
            let consumedAtValue = try consumedAt.toCBORValue()
            map = map.adding(key: "consumedAt", value: consumedAtValue)
            if let value = cipherSuite {
                let cipherSuiteValue = try value.toCBORValue()
                map = map.adding(key: "cipherSuite", value: cipherSuiteValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case keyPackageHash
            case usedInGroup
            case consumedAt
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
        
        
        public let totalUploaded: Int
        
        public let available: Int
        
        public let consumed: Int
        
        public let reserved: Int?
        
        public let consumedPackages: [ConsumedPackageView]?
        
        public let cursor: String?
        
        
        
        // Standard public initializer
        public init(
            
            
            totalUploaded: Int,
            
            available: Int,
            
            consumed: Int,
            
            reserved: Int? = nil,
            
            consumedPackages: [ConsumedPackageView]? = nil,
            
            cursor: String? = nil
            
            
        ) {
            
            
            self.totalUploaded = totalUploaded
            
            self.available = available
            
            self.consumed = consumed
            
            self.reserved = reserved
            
            self.consumedPackages = consumedPackages
            
            self.cursor = cursor
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.totalUploaded = try container.decode(Int.self, forKey: .totalUploaded)
            
            
            self.available = try container.decode(Int.self, forKey: .available)
            
            
            self.consumed = try container.decode(Int.self, forKey: .consumed)
            
            
            self.reserved = try container.decodeIfPresent(Int.self, forKey: .reserved)
            
            
            self.consumedPackages = try container.decodeIfPresent([ConsumedPackageView].self, forKey: .consumedPackages)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(totalUploaded, forKey: .totalUploaded)
            
            
            try container.encode(available, forKey: .available)
            
            
            try container.encode(consumed, forKey: .consumed)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(reserved, forKey: .reserved)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(consumedPackages, forKey: .consumedPackages)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let totalUploadedValue = try totalUploaded.toCBORValue()
            map = map.adding(key: "totalUploaded", value: totalUploadedValue)
            
            
            
            let availableValue = try available.toCBORValue()
            map = map.adding(key: "available", value: availableValue)
            
            
            
            let consumedValue = try consumed.toCBORValue()
            map = map.adding(key: "consumed", value: consumedValue)
            
            
            
            if let value = reserved {
                // Encode optional property even if it's an empty array for CBOR
                let reservedValue = try value.toCBORValue()
                map = map.adding(key: "reserved", value: reservedValue)
            }
            
            
            
            if let value = consumedPackages {
                // Encode optional property even if it's an empty array for CBOR
                let consumedPackagesValue = try value.toCBORValue()
                map = map.adding(key: "consumedPackages", value: consumedPackagesValue)
            }
            
            
            
            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case totalUploaded
            case available
            case consumed
            case reserved
            case consumedPackages
            case cursor
        }
        
    }




}



extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - getKeyPackageStatus

    /// Get key package statistics and consumption history for the authenticated user. Helps clients detect missing bundles before processing Welcome messages.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getKeyPackageStatus(input: BlueCatbirdMlsGetKeyPackageStatus.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetKeyPackageStatus.Output?) {
        let endpoint = "blue.catbird.mls.getKeyPackageStatus"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getKeyPackageStatus")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetKeyPackageStatus.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getKeyPackageStatus: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

