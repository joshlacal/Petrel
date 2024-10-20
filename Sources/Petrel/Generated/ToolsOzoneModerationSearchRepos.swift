import Foundation
import ZippyJSON

// lexicon: 1, id: tools.ozone.moderation.searchRepos

public enum ToolsOzoneModerationSearchRepos {
    public static let typeIdentifier = "tools.ozone.moderation.searchRepos"
    public struct Parameters: Parametrizable {
        public let term: String?
        public let q: String?
        public let limit: Int?
        public let cursor: String?

        public init(
            term: String? = nil,
            q: String? = nil,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.term = term
            self.q = q
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let repos: [ToolsOzoneModerationDefs.RepoView]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            repos: [ToolsOzoneModerationDefs.RepoView]

        ) {
            self.cursor = cursor

            self.repos = repos
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Moderation {
    /// Find repositories based on a search term.
    func searchRepos(input: ToolsOzoneModerationSearchRepos.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneModerationSearchRepos.Output?) {
        let endpoint = "tools.ozone.moderation.searchRepos"

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
        let decodedData = try? decoder.decode(ToolsOzoneModerationSearchRepos.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
