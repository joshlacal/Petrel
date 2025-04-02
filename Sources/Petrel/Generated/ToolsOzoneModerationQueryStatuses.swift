import Foundation

// lexicon: 1, id: tools.ozone.moderation.queryStatuses

public enum ToolsOzoneModerationQueryStatuses {
    public static let typeIdentifier = "tools.ozone.moderation.queryStatuses"
    public struct Parameters: Parametrizable {
        public let queueCount: Int?
        public let queueIndex: Int?
        public let queueSeed: String?
        public let includeAllUserRecords: Bool?
        public let subject: URI?
        public let comment: String?
        public let reportedAfter: ATProtocolDate?
        public let reportedBefore: ATProtocolDate?
        public let reviewedAfter: ATProtocolDate?
        public let hostingDeletedAfter: ATProtocolDate?
        public let hostingDeletedBefore: ATProtocolDate?
        public let hostingUpdatedAfter: ATProtocolDate?
        public let hostingUpdatedBefore: ATProtocolDate?
        public let hostingStatuses: [String]?
        public let reviewedBefore: ATProtocolDate?
        public let includeMuted: Bool?
        public let onlyMuted: Bool?
        public let reviewState: String?
        public let ignoreSubjects: [URI]?
        public let lastReviewedBy: DID?
        public let sortField: String?
        public let sortDirection: String?
        public let takendown: Bool?
        public let appealed: Bool?
        public let limit: Int?
        public let tags: [String]?
        public let excludeTags: [String]?
        public let cursor: String?
        public let collections: [NSID]?
        public let subjectType: String?
        public let minAccountSuspendCount: Int?
        public let minReportedRecordsCount: Int?
        public let minTakendownRecordsCount: Int?
        public let minPriorityScore: Int?

        public init(
            queueCount: Int? = nil,
            queueIndex: Int? = nil,
            queueSeed: String? = nil,
            includeAllUserRecords: Bool? = nil,
            subject: URI? = nil,
            comment: String? = nil,
            reportedAfter: ATProtocolDate? = nil,
            reportedBefore: ATProtocolDate? = nil,
            reviewedAfter: ATProtocolDate? = nil,
            hostingDeletedAfter: ATProtocolDate? = nil,
            hostingDeletedBefore: ATProtocolDate? = nil,
            hostingUpdatedAfter: ATProtocolDate? = nil,
            hostingUpdatedBefore: ATProtocolDate? = nil,
            hostingStatuses: [String]? = nil,
            reviewedBefore: ATProtocolDate? = nil,
            includeMuted: Bool? = nil,
            onlyMuted: Bool? = nil,
            reviewState: String? = nil,
            ignoreSubjects: [URI]? = nil,
            lastReviewedBy: DID? = nil,
            sortField: String? = nil,
            sortDirection: String? = nil,
            takendown: Bool? = nil,
            appealed: Bool? = nil,
            limit: Int? = nil,
            tags: [String]? = nil,
            excludeTags: [String]? = nil,
            cursor: String? = nil,
            collections: [NSID]? = nil,
            subjectType: String? = nil,
            minAccountSuspendCount: Int? = nil,
            minReportedRecordsCount: Int? = nil,
            minTakendownRecordsCount: Int? = nil,
            minPriorityScore: Int? = nil
        ) {
            self.queueCount = queueCount
            self.queueIndex = queueIndex
            self.queueSeed = queueSeed
            self.includeAllUserRecords = includeAllUserRecords
            self.subject = subject
            self.comment = comment
            self.reportedAfter = reportedAfter
            self.reportedBefore = reportedBefore
            self.reviewedAfter = reviewedAfter
            self.hostingDeletedAfter = hostingDeletedAfter
            self.hostingDeletedBefore = hostingDeletedBefore
            self.hostingUpdatedAfter = hostingUpdatedAfter
            self.hostingUpdatedBefore = hostingUpdatedBefore
            self.hostingStatuses = hostingStatuses
            self.reviewedBefore = reviewedBefore
            self.includeMuted = includeMuted
            self.onlyMuted = onlyMuted
            self.reviewState = reviewState
            self.ignoreSubjects = ignoreSubjects
            self.lastReviewedBy = lastReviewedBy
            self.sortField = sortField
            self.sortDirection = sortDirection
            self.takendown = takendown
            self.appealed = appealed
            self.limit = limit
            self.tags = tags
            self.excludeTags = excludeTags
            self.cursor = cursor
            self.collections = collections
            self.subjectType = subjectType
            self.minAccountSuspendCount = minAccountSuspendCount
            self.minReportedRecordsCount = minReportedRecordsCount
            self.minTakendownRecordsCount = minTakendownRecordsCount
            self.minPriorityScore = minPriorityScore
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let subjectStatuses: [ToolsOzoneModerationDefs.SubjectStatusView]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            subjectStatuses: [ToolsOzoneModerationDefs.SubjectStatusView]

        ) {
            self.cursor = cursor

            self.subjectStatuses = subjectStatuses
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            subjectStatuses = try container.decode([ToolsOzoneModerationDefs.SubjectStatusView].self, forKey: .subjectStatuses)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(subjectStatuses, forKey: .subjectStatuses)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR

                let cursorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let subjectStatusesValue = try (subjectStatuses as? DAGCBOREncodable)?.toCBORValue() ?? subjectStatuses
            map = map.adding(key: "subjectStatuses", value: subjectStatusesValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case subjectStatuses
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Moderation {
    /// View moderation statuses of subjects (record or repo).
    func queryStatuses(input: ToolsOzoneModerationQueryStatuses.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneModerationQueryStatuses.Output?) {
        let endpoint = "tools.ozone.moderation.queryStatuses"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneModerationQueryStatuses.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
