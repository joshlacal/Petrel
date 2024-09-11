import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.sync.requestCrawl

public enum ComAtprotoSyncRequestCrawl {
    public static let typeIdentifier = "com.atproto.sync.requestCrawl"
    public struct Input: ATProtocolCodable {
        public let hostname: String

        // Standard public initializer
        public init(hostname: String) {
            self.hostname = hostname
        }
    }
}

public extension ATProtoClient.Com.Atproto.Sync {
    /// Request a service to persistently crawl hosted repos. Expected use is new PDS instances declaring their existence to Relays. Does not require auth.
    func requestCrawl(
        input: ComAtprotoSyncRequestCrawl.Input,

        duringInitialSetup: Bool = false
    ) async throws -> Int {
        let endpoint = "/com.atproto.sync.requestCrawl"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        return responseCode
    }
}
