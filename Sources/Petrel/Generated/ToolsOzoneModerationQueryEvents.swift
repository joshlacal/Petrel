import Foundation
internal import ZippyJSON

// lexicon: 1, id: tools.ozone.moderation.queryEvents

public enum ToolsOzoneModerationQueryEvents {
    public static let typeIdentifier = "tools.ozone.moderation.queryEvents"
    public struct Parameters: Parametrizable {
        public let types: [String]?
        public let createdBy: String?
        public let sortDirection: String?
        public let createdAfter: ATProtocolDate?
        public let createdBefore: ATProtocolDate?
        public let subject: URI?
        public let includeAllUserRecords: Bool?
        public let limit: Int?
        public let hasComment: Bool?
        public let comment: String?
        public let addedLabels: [String]?
        public let removedLabels: [String]?
        public let addedTags: [String]?
        public let removedTags: [String]?
        public let reportTypes: [String]?
        public let cursor: String?

        public init(
            types: [String]? = nil,
            createdBy: String? = nil,
            sortDirection: String? = nil,
            createdAfter: ATProtocolDate? = nil,
            createdBefore: ATProtocolDate? = nil,
            subject: URI? = nil,
            includeAllUserRecords: Bool? = nil,
            limit: Int? = nil,
            hasComment: Bool? = nil,
            comment: String? = nil,
            addedLabels: [String]? = nil,
            removedLabels: [String]? = nil,
            addedTags: [String]? = nil,
            removedTags: [String]? = nil,
            reportTypes: [String]? = nil,
            cursor: String? = nil
        ) {
            self.types = types
            self.createdBy = createdBy
            self.sortDirection = sortDirection
            self.createdAfter = createdAfter
            self.createdBefore = createdBefore
            self.subject = subject
            self.includeAllUserRecords = includeAllUserRecords
            self.limit = limit
            self.hasComment = hasComment
            self.comment = comment
            self.addedLabels = addedLabels
            self.removedLabels = removedLabels
            self.addedTags = addedTags
            self.removedTags = removedTags
            self.reportTypes = reportTypes
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let events: [ToolsOzoneModerationDefs.ModEventView]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            events: [ToolsOzoneModerationDefs.ModEventView]
        ) {
            self.cursor = cursor

            self.events = events
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Moderation {
    /// List moderation events related to a subject.
    func queryEvents(input: ToolsOzoneModerationQueryEvents.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneModerationQueryEvents.Output?) {
        let endpoint = "/tools.ozone.moderation.queryEvents"

        let queryItems = input.asQueryItems()
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: false)
        let responseCode = response.statusCode

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneModerationQueryEvents.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
