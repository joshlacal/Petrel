import Foundation
import ZippyJSON

// lexicon: 1, id: tools.ozone.moderation.queryStatuses

public enum ToolsOzoneModerationQueryStatuses {
    public static let typeIdentifier = "tools.ozone.moderation.queryStatuses"
    public struct Parameters: Parametrizable {
        public let includeAllUserRecords: Bool?
        public let subject: URI?
        public let comment: String?
        public let reportedAfter: ATProtocolDate?
        public let reportedBefore: ATProtocolDate?
        public let reviewedAfter: ATProtocolDate?
        public let reviewedBefore: ATProtocolDate?
        public let includeMuted: Bool?
        public let onlyMuted: Bool?
        public let reviewState: String?
        public let ignoreSubjects: [URI]?
        public let lastReviewedBy: String?
        public let sortField: String?
        public let sortDirection: String?
        public let takendown: Bool?
        public let appealed: Bool?
        public let limit: Int?
        public let tags: [String]?
        public let excludeTags: [String]?
        public let cursor: String?

        public init(
            includeAllUserRecords: Bool? = nil,
            subject: URI? = nil,
            comment: String? = nil,
            reportedAfter: ATProtocolDate? = nil,
            reportedBefore: ATProtocolDate? = nil,
            reviewedAfter: ATProtocolDate? = nil,
            reviewedBefore: ATProtocolDate? = nil,
            includeMuted: Bool? = nil,
            onlyMuted: Bool? = nil,
            reviewState: String? = nil,
            ignoreSubjects: [URI]? = nil,
            lastReviewedBy: String? = nil,
            sortField: String? = nil,
            sortDirection: String? = nil,
            takendown: Bool? = nil,
            appealed: Bool? = nil,
            limit: Int? = nil,
            tags: [String]? = nil,
            excludeTags: [String]? = nil,
            cursor: String? = nil
        ) {
            self.includeAllUserRecords = includeAllUserRecords
            self.subject = subject
            self.comment = comment
            self.reportedAfter = reportedAfter
            self.reportedBefore = reportedBefore
            self.reviewedAfter = reviewedAfter
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

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneModerationQueryStatuses.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
