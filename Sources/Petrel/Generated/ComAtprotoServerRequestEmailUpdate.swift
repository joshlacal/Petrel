import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.server.requestEmailUpdate

public enum ComAtprotoServerRequestEmailUpdate {
    public static let typeIdentifier = "com.atproto.server.requestEmailUpdate"

    public struct Output: ATProtocolCodable {
        public let tokenRequired: Bool

        // Standard public initializer
        public init(
            tokenRequired: Bool
        ) {
            self.tokenRequired = tokenRequired
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Request a token in order to update email.
    func requestEmailUpdate(
        duringInitialSetup: Bool = false
    ) async throws -> (responseCode: Int, data: ComAtprotoServerRequestEmailUpdate.Output?) {
        let endpoint = "/com.atproto.server.requestEmailUpdate"

        let requestData: Data? = nil
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        let decodedData = try? ZippyJSONDecoder().decode(ComAtprotoServerRequestEmailUpdate.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
