import Foundation



// lexicon: 1, id: blue.catbird.mls.getAdminStats


public struct BlueCatbirdMlsGetAdminStats { 

    public static let typeIdentifier = "blue.catbird.mls.getAdminStats"
        
public struct ModerationStats: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.getAdminStats#moderationStats"
            public let totalReports: Int
            public let pendingReports: Int
            public let resolvedReports: Int
            public let totalRemovals: Int
            public let blockConflictsResolved: Int
            public let reportsByCategory: ReportCategoryCounts?
            public let averageResolutionTimeHours: Int?

        // Standard initializer
        public init(
            totalReports: Int, pendingReports: Int, resolvedReports: Int, totalRemovals: Int, blockConflictsResolved: Int, reportsByCategory: ReportCategoryCounts?, averageResolutionTimeHours: Int?
        ) {
            
            self.totalReports = totalReports
            self.pendingReports = pendingReports
            self.resolvedReports = resolvedReports
            self.totalRemovals = totalRemovals
            self.blockConflictsResolved = blockConflictsResolved
            self.reportsByCategory = reportsByCategory
            self.averageResolutionTimeHours = averageResolutionTimeHours
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.totalReports = try container.decode(Int.self, forKey: .totalReports)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'totalReports': \(error)")
                
                throw error
            }
            do {
                
                
                self.pendingReports = try container.decode(Int.self, forKey: .pendingReports)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'pendingReports': \(error)")
                
                throw error
            }
            do {
                
                
                self.resolvedReports = try container.decode(Int.self, forKey: .resolvedReports)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'resolvedReports': \(error)")
                
                throw error
            }
            do {
                
                
                self.totalRemovals = try container.decode(Int.self, forKey: .totalRemovals)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'totalRemovals': \(error)")
                
                throw error
            }
            do {
                
                
                self.blockConflictsResolved = try container.decode(Int.self, forKey: .blockConflictsResolved)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'blockConflictsResolved': \(error)")
                
                throw error
            }
            do {
                
                
                self.reportsByCategory = try container.decodeIfPresent(ReportCategoryCounts.self, forKey: .reportsByCategory)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'reportsByCategory': \(error)")
                
                throw error
            }
            do {
                
                
                self.averageResolutionTimeHours = try container.decodeIfPresent(Int.self, forKey: .averageResolutionTimeHours)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'averageResolutionTimeHours': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(totalReports, forKey: .totalReports)
            
            
            
            
            try container.encode(pendingReports, forKey: .pendingReports)
            
            
            
            
            try container.encode(resolvedReports, forKey: .resolvedReports)
            
            
            
            
            try container.encode(totalRemovals, forKey: .totalRemovals)
            
            
            
            
            try container.encode(blockConflictsResolved, forKey: .blockConflictsResolved)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(reportsByCategory, forKey: .reportsByCategory)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(averageResolutionTimeHours, forKey: .averageResolutionTimeHours)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(totalReports)
            hasher.combine(pendingReports)
            hasher.combine(resolvedReports)
            hasher.combine(totalRemovals)
            hasher.combine(blockConflictsResolved)
            if let value = reportsByCategory {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = averageResolutionTimeHours {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.totalReports != other.totalReports {
                return false
            }
            
            
            
            
            if self.pendingReports != other.pendingReports {
                return false
            }
            
            
            
            
            if self.resolvedReports != other.resolvedReports {
                return false
            }
            
            
            
            
            if self.totalRemovals != other.totalRemovals {
                return false
            }
            
            
            
            
            if self.blockConflictsResolved != other.blockConflictsResolved {
                return false
            }
            
            
            
            
            if reportsByCategory != other.reportsByCategory {
                return false
            }
            
            
            
            
            if averageResolutionTimeHours != other.averageResolutionTimeHours {
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

            
            
            
            
            let totalReportsValue = try totalReports.toCBORValue()
            map = map.adding(key: "totalReports", value: totalReportsValue)
            
            
            
            
            
            
            let pendingReportsValue = try pendingReports.toCBORValue()
            map = map.adding(key: "pendingReports", value: pendingReportsValue)
            
            
            
            
            
            
            let resolvedReportsValue = try resolvedReports.toCBORValue()
            map = map.adding(key: "resolvedReports", value: resolvedReportsValue)
            
            
            
            
            
            
            let totalRemovalsValue = try totalRemovals.toCBORValue()
            map = map.adding(key: "totalRemovals", value: totalRemovalsValue)
            
            
            
            
            
            
            let blockConflictsResolvedValue = try blockConflictsResolved.toCBORValue()
            map = map.adding(key: "blockConflictsResolved", value: blockConflictsResolvedValue)
            
            
            
            
            
            if let value = reportsByCategory {
                // Encode optional property even if it's an empty array for CBOR
                
                let reportsByCategoryValue = try value.toCBORValue()
                map = map.adding(key: "reportsByCategory", value: reportsByCategoryValue)
            }
            
            
            
            
            
            if let value = averageResolutionTimeHours {
                // Encode optional property even if it's an empty array for CBOR
                
                let averageResolutionTimeHoursValue = try value.toCBORValue()
                map = map.adding(key: "averageResolutionTimeHours", value: averageResolutionTimeHoursValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case totalReports
            case pendingReports
            case resolvedReports
            case totalRemovals
            case blockConflictsResolved
            case reportsByCategory
            case averageResolutionTimeHours
        }
    }
        
public struct ReportCategoryCounts: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.getAdminStats#reportCategoryCounts"
            public let harassment: Int?
            public let spam: Int?
            public let hateSpeech: Int?
            public let violence: Int?
            public let sexualContent: Int?
            public let impersonation: Int?
            public let privacyViolation: Int?
            public let otherCategory: Int?

        // Standard initializer
        public init(
            harassment: Int?, spam: Int?, hateSpeech: Int?, violence: Int?, sexualContent: Int?, impersonation: Int?, privacyViolation: Int?, otherCategory: Int?
        ) {
            
            self.harassment = harassment
            self.spam = spam
            self.hateSpeech = hateSpeech
            self.violence = violence
            self.sexualContent = sexualContent
            self.impersonation = impersonation
            self.privacyViolation = privacyViolation
            self.otherCategory = otherCategory
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.harassment = try container.decodeIfPresent(Int.self, forKey: .harassment)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'harassment': \(error)")
                
                throw error
            }
            do {
                
                
                self.spam = try container.decodeIfPresent(Int.self, forKey: .spam)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'spam': \(error)")
                
                throw error
            }
            do {
                
                
                self.hateSpeech = try container.decodeIfPresent(Int.self, forKey: .hateSpeech)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'hateSpeech': \(error)")
                
                throw error
            }
            do {
                
                
                self.violence = try container.decodeIfPresent(Int.self, forKey: .violence)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'violence': \(error)")
                
                throw error
            }
            do {
                
                
                self.sexualContent = try container.decodeIfPresent(Int.self, forKey: .sexualContent)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'sexualContent': \(error)")
                
                throw error
            }
            do {
                
                
                self.impersonation = try container.decodeIfPresent(Int.self, forKey: .impersonation)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'impersonation': \(error)")
                
                throw error
            }
            do {
                
                
                self.privacyViolation = try container.decodeIfPresent(Int.self, forKey: .privacyViolation)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'privacyViolation': \(error)")
                
                throw error
            }
            do {
                
                
                self.otherCategory = try container.decodeIfPresent(Int.self, forKey: .otherCategory)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'otherCategory': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(harassment, forKey: .harassment)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(spam, forKey: .spam)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(hateSpeech, forKey: .hateSpeech)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(violence, forKey: .violence)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(sexualContent, forKey: .sexualContent)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(impersonation, forKey: .impersonation)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(privacyViolation, forKey: .privacyViolation)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(otherCategory, forKey: .otherCategory)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = harassment {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = spam {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = hateSpeech {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = violence {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = sexualContent {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = impersonation {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = privacyViolation {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = otherCategory {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if harassment != other.harassment {
                return false
            }
            
            
            
            
            if spam != other.spam {
                return false
            }
            
            
            
            
            if hateSpeech != other.hateSpeech {
                return false
            }
            
            
            
            
            if violence != other.violence {
                return false
            }
            
            
            
            
            if sexualContent != other.sexualContent {
                return false
            }
            
            
            
            
            if impersonation != other.impersonation {
                return false
            }
            
            
            
            
            if privacyViolation != other.privacyViolation {
                return false
            }
            
            
            
            
            if otherCategory != other.otherCategory {
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

            
            
            
            if let value = harassment {
                // Encode optional property even if it's an empty array for CBOR
                
                let harassmentValue = try value.toCBORValue()
                map = map.adding(key: "harassment", value: harassmentValue)
            }
            
            
            
            
            
            if let value = spam {
                // Encode optional property even if it's an empty array for CBOR
                
                let spamValue = try value.toCBORValue()
                map = map.adding(key: "spam", value: spamValue)
            }
            
            
            
            
            
            if let value = hateSpeech {
                // Encode optional property even if it's an empty array for CBOR
                
                let hateSpeechValue = try value.toCBORValue()
                map = map.adding(key: "hateSpeech", value: hateSpeechValue)
            }
            
            
            
            
            
            if let value = violence {
                // Encode optional property even if it's an empty array for CBOR
                
                let violenceValue = try value.toCBORValue()
                map = map.adding(key: "violence", value: violenceValue)
            }
            
            
            
            
            
            if let value = sexualContent {
                // Encode optional property even if it's an empty array for CBOR
                
                let sexualContentValue = try value.toCBORValue()
                map = map.adding(key: "sexualContent", value: sexualContentValue)
            }
            
            
            
            
            
            if let value = impersonation {
                // Encode optional property even if it's an empty array for CBOR
                
                let impersonationValue = try value.toCBORValue()
                map = map.adding(key: "impersonation", value: impersonationValue)
            }
            
            
            
            
            
            if let value = privacyViolation {
                // Encode optional property even if it's an empty array for CBOR
                
                let privacyViolationValue = try value.toCBORValue()
                map = map.adding(key: "privacyViolation", value: privacyViolationValue)
            }
            
            
            
            
            
            if let value = otherCategory {
                // Encode optional property even if it's an empty array for CBOR
                
                let otherCategoryValue = try value.toCBORValue()
                map = map.adding(key: "otherCategory", value: otherCategoryValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case harassment
            case spam
            case hateSpeech
            case violence
            case sexualContent
            case impersonation
            case privacyViolation
            case otherCategory
        }
    }    
public struct Parameters: Parametrizable {
        public let convoId: String?
        public let since: ATProtocolDate?
        
        public init(
            convoId: String? = nil, 
            since: ATProtocolDate? = nil
            ) {
            self.convoId = convoId
            self.since = since
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let stats: ModerationStats
        
        public let generatedAt: ATProtocolDate
        
        public let convoId: String?
        
        
        
        // Standard public initializer
        public init(
            
            
            stats: ModerationStats,
            
            generatedAt: ATProtocolDate,
            
            convoId: String? = nil
            
            
        ) {
            
            
            self.stats = stats
            
            self.generatedAt = generatedAt
            
            self.convoId = convoId
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.stats = try container.decode(ModerationStats.self, forKey: .stats)
            
            
            self.generatedAt = try container.decode(ATProtocolDate.self, forKey: .generatedAt)
            
            
            self.convoId = try container.decodeIfPresent(String.self, forKey: .convoId)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(stats, forKey: .stats)
            
            
            try container.encode(generatedAt, forKey: .generatedAt)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(convoId, forKey: .convoId)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let statsValue = try stats.toCBORValue()
            map = map.adding(key: "stats", value: statsValue)
            
            
            
            let generatedAtValue = try generatedAt.toCBORValue()
            map = map.adding(key: "generatedAt", value: generatedAtValue)
            
            
            
            if let value = convoId {
                // Encode optional property even if it's an empty array for CBOR
                let convoIdValue = try value.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case stats
            case generatedAt
            case convoId
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                /// User is not authorized to view moderation statistics
                case notAuthorized = "NotAuthorized"
                /// Conversation not found (when convoId is specified)
                case convoNotFound = "ConvoNotFound"
            public var description: String {
                return self.rawValue
            }
        }



}



extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - getAdminStats

    /// Get moderation statistics for App Store compliance demonstration Query moderation and admin action statistics. Returns aggregate counts of reports, removals, and block conflicts resolved. Used for App Store review to demonstrate active moderation capabilities. Only accessible to conversation admins.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getAdminStats(input: BlueCatbirdMlsGetAdminStats.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetAdminStats.Output?) {
        let endpoint = "blue.catbird.mls.getAdminStats"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getAdminStats")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetAdminStats.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getAdminStats: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Try to parse structured error response
            if let atprotoError = ATProtoErrorParser.parse(
                data: responseData,
                statusCode: responseCode,
                errorType: BlueCatbirdMlsGetAdminStats.Error.self
            ) {
                throw atprotoError
            }
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

