import Foundation

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
        public let collections: [String]?
        public let subjectType: String?
        public let includeAllUserRecords: Bool?
        public let limit: Int?
        public let hasComment: Bool?
        public let comment: String?
        public let addedLabels: [String]?
        public let removedLabels: [String]?
        public let addedTags: [String]?
        public let removedTags: [String]?
        public let reportTypes: [String]?
        public let policies: [String]?
        public let cursor: String?

        public init(
            types: [String]? = nil,
            createdBy: String? = nil,
            sortDirection: String? = nil,
            createdAfter: ATProtocolDate? = nil,
            createdBefore: ATProtocolDate? = nil,
            subject: URI? = nil,
            collections: [String]? = nil,
            subjectType: String? = nil,
            includeAllUserRecords: Bool? = nil,
            limit: Int? = nil,
            hasComment: Bool? = nil,
            comment: String? = nil,
            addedLabels: [String]? = nil,
            removedLabels: [String]? = nil,
            addedTags: [String]? = nil,
            removedTags: [String]? = nil,
            reportTypes: [String]? = nil,
            policies: [String]? = nil,
            cursor: String? = nil
        ) {
            self.types = types
            self.createdBy = createdBy
            self.sortDirection = sortDirection
            self.createdAfter = createdAfter
            self.createdBefore = createdBefore
            self.subject = subject
            self.collections = collections
            self.subjectType = subjectType
            self.includeAllUserRecords = includeAllUserRecords
            self.limit = limit
            self.hasComment = hasComment
            self.comment = comment
            self.addedLabels = addedLabels
            self.removedLabels = removedLabels
            self.addedTags = addedTags
            self.removedTags = removedTags
            self.reportTypes = reportTypes
            self.policies = policies
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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            events = try container.decode([ToolsOzoneModerationDefs.ModEventView].self, forKey: .events)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            if let value = cursor {
                try container.encode(value, forKey: .cursor)
            }

            try container.encode(events, forKey: .events)
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case events
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Moderation {
    /// List moderation events related to a subject.
    func queryEvents(input: ToolsOzoneModerationQueryEvents.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneModerationQueryEvents.Output?) {
        let endpoint = "tools.ozone.moderation.queryEvents"

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
        let decodedData = try? decoder.decode(ToolsOzoneModerationQueryEvents.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
