import Foundation



// lexicon: 1, id: app.bsky.draft.updateDraft


public struct AppBskyDraftUpdateDraft { 

    public static let typeIdentifier = "app.bsky.draft.updateDraft"
public struct Input: ATProtocolCodable {
        public let draft: AppBskyDraftDefs.DraftWithId

        /// Standard public initializer
        public init(draft: AppBskyDraftDefs.DraftWithId) {
            self.draft = draft
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.draft = try container.decode(AppBskyDraftDefs.DraftWithId.self, forKey: .draft)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(draft, forKey: .draft)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let draftValue = try draft.toCBORValue()
            map = map.adding(key: "draft", value: draftValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case draft
        }
    }



}

extension ATProtoClient.App.Bsky.Draft {
    // MARK: - updateDraft

    /// Updates a draft using private storage (stash). If the draft ID points to a non-existing ID, the update will be silently ignored. This is done because updates don't enforce draft limit, so it accepts all writes, but will ignore invalid ones. Requires authentication.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func updateDraft(
        
        input: AppBskyDraftUpdateDraft.Input
        
    ) async throws -> Int {
        let endpoint = "app.bsky.draft.updateDraft"
        
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
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.draft.updateDraft")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        
        return responseCode
        
    }
    
}
                           

