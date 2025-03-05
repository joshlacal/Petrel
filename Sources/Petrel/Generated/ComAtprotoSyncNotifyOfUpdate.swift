import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.sync.notifyOfUpdate

public enum ComAtprotoSyncNotifyOfUpdate {
    public static let typeIdentifier = "com.atproto.sync.notifyOfUpdate"
    public struct Input: ATProtocolCodable {
        public let hostname: String

        // Standard public initializer
        public init(hostname: String) {
            self.hostname = hostname
        }
    }
}

public extension ATProtoClient.Com.Atproto.Sync {
    /// Notify a crawling service of a recent update, and that crawling should resume. Intended use is after a gap between repo stream events caused the crawling service to disconnect. Does not require auth; implemented by Relay. DEPRECATED: just use com.atproto.sync.requestCrawl
    func notifyOfUpdate(
        input: ComAtprotoSyncNotifyOfUpdate.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.sync.notifyOfUpdate"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
    }
}
