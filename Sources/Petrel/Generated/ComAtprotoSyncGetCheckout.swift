import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.sync.getCheckout

public enum ComAtprotoSyncGetCheckout {
    public static let typeIdentifier = "com.atproto.sync.getCheckout"
    public struct Parameters: Parametrizable {
        public let did: String

        public init(
            did: String
        ) {
            self.did = did
        }
    }

    public struct Output: ATProtocolCodable {
        // Standard public initializer
        public init() {}
    }
}

public extension ATProtoClient.Com.Atproto.Sync {
    /// DEPRECATED - please use com.atproto.sync.getRepo instead
    func getCheckout(input: ComAtprotoSyncGetCheckout.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetCheckout.Output?) {
        let endpoint = "/com.atproto.sync.getCheckout"

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
        let decodedData = try? decoder.decode(ComAtprotoSyncGetCheckout.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
