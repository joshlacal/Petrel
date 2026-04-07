import Foundation



// lexicon: 1, id: blue.catbird.mls.resolveReport


public struct BlueCatbirdMlsResolveReport { 

    public static let typeIdentifier = "blue.catbird.mls.resolveReport"
public struct Input: ATProtocolCodable {
        public let reportId: String
        public let action: String
        public let notes: String?

        /// Standard public initializer
        public init(reportId: String, action: String, notes: String? = nil) {
            self.reportId = reportId
            self.action = action
            self.notes = notes
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.reportId = try container.decode(String.self, forKey: .reportId)
            self.action = try container.decode(String.self, forKey: .action)
            self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(reportId, forKey: .reportId)
            try container.encode(action, forKey: .action)
            try container.encodeIfPresent(notes, forKey: .notes)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let reportIdValue = try reportId.toCBORValue()
            map = map.adding(key: "reportId", value: reportIdValue)
            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)
            if let value = notes {
                let notesValue = try value.toCBORValue()
                map = map.adding(key: "notes", value: notesValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case reportId
            case action
            case notes
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let ok: Bool
        
        
        
        // Standard public initializer
        public init(
            
            
            ok: Bool
            
            
        ) {
            
            
            self.ok = ok
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.ok = try container.decode(Bool.self, forKey: .ok)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(ok, forKey: .ok)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let okValue = try ok.toCBORValue()
            map = map.adding(key: "ok", value: okValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case ok
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case notAdmin = "NotAdmin.Caller is not an admin"
                case reportNotFound = "ReportNotFound.Report does not exist"
                case alreadyResolved = "AlreadyResolved.Report was already resolved"
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
    // MARK: - resolveReport

    /// Resolve a report with an action (admin-only) Mark a report as resolved with the action taken. Admin-only operation. Records resolution in audit trail.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func resolveReport(
        
        input: BlueCatbirdMlsResolveReport.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsResolveReport.Output?) {
        let endpoint = "blue.catbird.mls.resolveReport"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.resolveReport")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsResolveReport.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.resolveReport: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

