import Foundation



// lexicon: 1, id: blue.catbird.mls.publishKeyPackages


public struct BlueCatbirdMlsPublishKeyPackages { 

    public static let typeIdentifier = "blue.catbird.mls.publishKeyPackages"
        
public struct KeyPackageItem: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.publishKeyPackages#keyPackageItem"
            public let keyPackage: String
            public let cipherSuite: String
            public let expires: ATProtocolDate
            public let idempotencyKey: String?
            public let deviceId: String?
            public let credentialDid: String?

        public init(
            keyPackage: String, cipherSuite: String, expires: ATProtocolDate, idempotencyKey: String?, deviceId: String?, credentialDid: String?
        ) {
            self.keyPackage = keyPackage
            self.cipherSuite = cipherSuite
            self.expires = expires
            self.idempotencyKey = idempotencyKey
            self.deviceId = deviceId
            self.credentialDid = credentialDid
        }

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
            do {
                self.idempotencyKey = try container.decodeIfPresent(String.self, forKey: .idempotencyKey)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'idempotencyKey': \(error)")
                throw error
            }
            do {
                self.deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'deviceId': \(error)")
                throw error
            }
            do {
                self.credentialDid = try container.decodeIfPresent(String.self, forKey: .credentialDid)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'credentialDid': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(keyPackage, forKey: .keyPackage)
            try container.encode(cipherSuite, forKey: .cipherSuite)
            try container.encode(expires, forKey: .expires)
            try container.encodeIfPresent(idempotencyKey, forKey: .idempotencyKey)
            try container.encodeIfPresent(deviceId, forKey: .deviceId)
            try container.encodeIfPresent(credentialDid, forKey: .credentialDid)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(keyPackage)
            hasher.combine(cipherSuite)
            hasher.combine(expires)
            if let value = idempotencyKey {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = deviceId {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = credentialDid {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if keyPackage != other.keyPackage {
                return false
            }
            if cipherSuite != other.cipherSuite {
                return false
            }
            if expires != other.expires {
                return false
            }
            if idempotencyKey != other.idempotencyKey {
                return false
            }
            if deviceId != other.deviceId {
                return false
            }
            if credentialDid != other.credentialDid {
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
            let keyPackageValue = try keyPackage.toCBORValue()
            map = map.adding(key: "keyPackage", value: keyPackageValue)
            let cipherSuiteValue = try cipherSuite.toCBORValue()
            map = map.adding(key: "cipherSuite", value: cipherSuiteValue)
            let expiresValue = try expires.toCBORValue()
            map = map.adding(key: "expires", value: expiresValue)
            if let value = idempotencyKey {
                let idempotencyKeyValue = try value.toCBORValue()
                map = map.adding(key: "idempotencyKey", value: idempotencyKeyValue)
            }
            if let value = deviceId {
                let deviceIdValue = try value.toCBORValue()
                map = map.adding(key: "deviceId", value: deviceIdValue)
            }
            if let value = credentialDid {
                let credentialDidValue = try value.toCBORValue()
                map = map.adding(key: "credentialDid", value: credentialDidValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case keyPackage
            case cipherSuite
            case expires
            case idempotencyKey
            case deviceId
            case credentialDid
        }
    }
        
public struct BatchError: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.publishKeyPackages#batchError"
            public let index: Int
            public let error: String

        public init(
            index: Int, error: String
        ) {
            self.index = index
            self.error = error
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.index = try container.decode(Int.self, forKey: .index)
            } catch {
                LogManager.logError("Decoding error for required property 'index': \(error)")
                throw error
            }
            do {
                self.error = try container.decode(String.self, forKey: .error)
            } catch {
                LogManager.logError("Decoding error for required property 'error': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(index, forKey: .index)
            try container.encode(error, forKey: .error)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(index)
            hasher.combine(error)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if index != other.index {
                return false
            }
            if error != other.error {
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
            let indexValue = try index.toCBORValue()
            map = map.adding(key: "index", value: indexValue)
            let errorValue = try error.toCBORValue()
            map = map.adding(key: "error", value: errorValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case index
            case error
        }
    }
public struct Input: ATProtocolCodable {
        public let keyPackages: [KeyPackageItem]

        /// Standard public initializer
        public init(keyPackages: [KeyPackageItem]) {
            self.keyPackages = keyPackages
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.keyPackages = try container.decode([KeyPackageItem].self, forKey: .keyPackages)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(keyPackages, forKey: .keyPackages)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let keyPackagesValue = try keyPackages.toCBORValue()
            map = map.adding(key: "keyPackages", value: keyPackagesValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case keyPackages
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let succeeded: Int
        
        public let failed: Int
        
        public let errors: [BatchError]?
        
        
        
        // Standard public initializer
        public init(
            
            
            succeeded: Int,
            
            failed: Int,
            
            errors: [BatchError]? = nil
            
            
        ) {
            
            
            self.succeeded = succeeded
            
            self.failed = failed
            
            self.errors = errors
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.succeeded = try container.decode(Int.self, forKey: .succeeded)
            
            
            self.failed = try container.decode(Int.self, forKey: .failed)
            
            
            self.errors = try container.decodeIfPresent([BatchError].self, forKey: .errors)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(succeeded, forKey: .succeeded)
            
            
            try container.encode(failed, forKey: .failed)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(errors, forKey: .errors)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let succeededValue = try succeeded.toCBORValue()
            map = map.adding(key: "succeeded", value: succeededValue)
            
            
            
            let failedValue = try failed.toCBORValue()
            map = map.adding(key: "failed", value: failedValue)
            
            
            
            if let value = errors {
                // Encode optional property even if it's an empty array for CBOR
                let errorsValue = try value.toCBORValue()
                map = map.adding(key: "errors", value: errorsValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case succeeded
            case failed
            case errors
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case batchTooLarge = "BatchTooLarge.Batch size exceeds maximum of 100 key packages"
                case invalidBatch = "InvalidBatch.Batch validation failed (see errors array in response)"
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
    // MARK: - publishKeyPackages

    /// Publish multiple MLS key packages in a single batch request (up to 100 packages). More efficient than individual uploads for replenishing key package pools.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func publishKeyPackages(
        
        input: BlueCatbirdMlsPublishKeyPackages.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsPublishKeyPackages.Output?) {
        let endpoint = "blue.catbird.mls.publishKeyPackages"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.publishKeyPackages")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsPublishKeyPackages.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.publishKeyPackages: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

