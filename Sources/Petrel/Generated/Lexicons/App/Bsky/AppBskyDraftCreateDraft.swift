import Foundation

// lexicon: 1, id: app.bsky.draft.createDraft

public enum AppBskyDraftCreateDraft {
    public static let typeIdentifier = "app.bsky.draft.createDraft"
    public struct Input: ATProtocolCodable {
        public let draft: AppBskyDraftDefs.Draft

        /// Standard public initializer
        public init(draft: AppBskyDraftDefs.Draft) {
            self.draft = draft
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            draft = try container.decode(AppBskyDraftDefs.Draft.self, forKey: .draft)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(draft, forKey: .draft)
        }

        private enum CodingKeys: String, CodingKey {
            case draft
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let draftValue = try draft.toCBORValue()
            map = map.adding(key: "draft", value: draftValue)

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let id: String

        /// Standard public initializer
        public init(
            id: String

        ) {
            self.id = id
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            id = try container.decode(String.self, forKey: .id)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(id, forKey: .id)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case id
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case draftLimitReached = "DraftLimitReached.Trying to insert a new draft when the limit was already reached."
        public var description: String {
            return rawValue
        }

        public var errorName: String {
            // Extract just the error name from the raw value
            let parts = rawValue.split(separator: ".")
            return String(parts.first ?? "")
        }
    }
}

public extension ATProtoClient.App.Bsky.Draft {
    // MARK: - createDraft

    /// Inserts a draft using private storage (stash). An upper limit of drafts might be enforced. Requires authentication.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func createDraft(
        input: AppBskyDraftCreateDraft.Input

    ) async throws -> (responseCode: Int, data: AppBskyDraftCreateDraft.Output?) {
        let endpoint = "app.bsky.draft.createDraft"

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
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.draft.createDraft")
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
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(AppBskyDraftCreateDraft.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.draft.createDraft: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
