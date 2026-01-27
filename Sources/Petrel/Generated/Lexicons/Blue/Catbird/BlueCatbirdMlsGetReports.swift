import Foundation



// lexicon: 1, id: blue.catbird.mls.getReports


public struct BlueCatbirdMlsGetReports { 

    public static let typeIdentifier = "blue.catbird.mls.getReports"
        
public struct ReportView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.getReports#reportView"
            public let id: String
            public let reporterDid: DID
            public let reportedDid: DID
            public let encryptedContent: Bytes
            public let createdAt: ATProtocolDate
            public let status: String
            public let resolvedBy: DID?
            public let resolvedAt: ATProtocolDate?

        // Standard initializer
        public init(
            id: String, reporterDid: DID, reportedDid: DID, encryptedContent: Bytes, createdAt: ATProtocolDate, status: String, resolvedBy: DID?, resolvedAt: ATProtocolDate?
        ) {
            
            self.id = id
            self.reporterDid = reporterDid
            self.reportedDid = reportedDid
            self.encryptedContent = encryptedContent
            self.createdAt = createdAt
            self.status = status
            self.resolvedBy = resolvedBy
            self.resolvedAt = resolvedAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.id = try container.decode(String.self, forKey: .id)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'id': \(error)")
                
                throw error
            }
            do {
                
                
                self.reporterDid = try container.decode(DID.self, forKey: .reporterDid)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'reporterDid': \(error)")
                
                throw error
            }
            do {
                
                
                self.reportedDid = try container.decode(DID.self, forKey: .reportedDid)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'reportedDid': \(error)")
                
                throw error
            }
            do {
                
                
                self.encryptedContent = try container.decode(Bytes.self, forKey: .encryptedContent)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'encryptedContent': \(error)")
                
                throw error
            }
            do {
                
                
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                
                throw error
            }
            do {
                
                
                self.status = try container.decode(String.self, forKey: .status)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'status': \(error)")
                
                throw error
            }
            do {
                
                
                self.resolvedBy = try container.decodeIfPresent(DID.self, forKey: .resolvedBy)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'resolvedBy': \(error)")
                
                throw error
            }
            do {
                
                
                self.resolvedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .resolvedAt)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'resolvedAt': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(id, forKey: .id)
            
            
            
            
            try container.encode(reporterDid, forKey: .reporterDid)
            
            
            
            
            try container.encode(reportedDid, forKey: .reportedDid)
            
            
            
            
            try container.encode(encryptedContent, forKey: .encryptedContent)
            
            
            
            
            try container.encode(createdAt, forKey: .createdAt)
            
            
            
            
            try container.encode(status, forKey: .status)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(resolvedBy, forKey: .resolvedBy)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(resolvedAt, forKey: .resolvedAt)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(reporterDid)
            hasher.combine(reportedDid)
            hasher.combine(encryptedContent)
            hasher.combine(createdAt)
            hasher.combine(status)
            if let value = resolvedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = resolvedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.id != other.id {
                return false
            }
            
            
            
            
            if self.reporterDid != other.reporterDid {
                return false
            }
            
            
            
            
            if self.reportedDid != other.reportedDid {
                return false
            }
            
            
            
            
            if self.encryptedContent != other.encryptedContent {
                return false
            }
            
            
            
            
            if self.createdAt != other.createdAt {
                return false
            }
            
            
            
            
            if self.status != other.status {
                return false
            }
            
            
            
            
            if resolvedBy != other.resolvedBy {
                return false
            }
            
            
            
            
            if resolvedAt != other.resolvedAt {
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

            
            
            
            
            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)
            
            
            
            
            
            
            let reporterDidValue = try reporterDid.toCBORValue()
            map = map.adding(key: "reporterDid", value: reporterDidValue)
            
            
            
            
            
            
            let reportedDidValue = try reportedDid.toCBORValue()
            map = map.adding(key: "reportedDid", value: reportedDidValue)
            
            
            
            
            
            
            let encryptedContentValue = try encryptedContent.toCBORValue()
            map = map.adding(key: "encryptedContent", value: encryptedContentValue)
            
            
            
            
            
            
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            
            
            
            
            
            
            let statusValue = try status.toCBORValue()
            map = map.adding(key: "status", value: statusValue)
            
            
            
            
            
            if let value = resolvedBy {
                // Encode optional property even if it's an empty array for CBOR
                
                let resolvedByValue = try value.toCBORValue()
                map = map.adding(key: "resolvedBy", value: resolvedByValue)
            }
            
            
            
            
            
            if let value = resolvedAt {
                // Encode optional property even if it's an empty array for CBOR
                
                let resolvedAtValue = try value.toCBORValue()
                map = map.adding(key: "resolvedAt", value: resolvedAtValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case reporterDid
            case reportedDid
            case encryptedContent
            case createdAt
            case status
            case resolvedBy
            case resolvedAt
        }
    }    
public struct Parameters: Parametrizable {
        public let convoId: String
        public let status: String?
        public let limit: Int?
        
        public init(
            convoId: String, 
            status: String? = nil, 
            limit: Int? = nil
            ) {
            self.convoId = convoId
            self.status = status
            self.limit = limit
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let reports: [ReportView]
        
        
        
        // Standard public initializer
        public init(
            
            
            reports: [ReportView]
            
            
        ) {
            
            
            self.reports = reports
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.reports = try container.decode([ReportView].self, forKey: .reports)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(reports, forKey: .reports)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let reportsValue = try reports.toCBORValue()
            map = map.adding(key: "reports", value: reportsValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case reports
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case notAdmin = "NotAdmin.Caller is not an admin"
                case convoNotFound = "ConvoNotFound.Conversation not found"
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
    // MARK: - getReports

    /// Get reports for a conversation (admin-only) Retrieve reports for a conversation. Admin-only endpoint. Returns encrypted report blobs that admins must decrypt locally using MLS group key.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getReports(input: BlueCatbirdMlsGetReports.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetReports.Output?) {
        let endpoint = "blue.catbird.mls.getReports"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getReports")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetReports.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getReports: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

