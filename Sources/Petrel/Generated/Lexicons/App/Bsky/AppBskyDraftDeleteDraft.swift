import Foundation

// lexicon: 1, id: app.bsky.draft.deleteDraft

public enum AppBskyDraftDeleteDraft {
    public static let typeIdentifier = "app.bsky.draft.deleteDraft"
    public struct Input: ATProtocolCodable {
        public let id: TID

        /// Standard public initializer
        public init(id: TID) {
            self.id = id
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            id = try container.decode(TID.self, forKey: .id)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(id, forKey: .id)
        }

        private enum CodingKeys: String, CodingKey {
            case id
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)

            return map
        }
    }
}

public extension ATProtoClient.App.Bsky.Draft {
    // MARK: - deleteDraft

    /// Deletes a draft by ID. Requires authentication.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func deleteDraft(
        input: AppBskyDraftDeleteDraft.Input

    ) async throws -> Int {
        let endpoint = "app.bsky.draft.deleteDraft"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.draft.deleteDraft")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        return response.statusCode
    }
}
