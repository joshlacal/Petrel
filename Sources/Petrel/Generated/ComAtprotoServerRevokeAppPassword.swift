import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.server.revokeAppPassword

public enum ComAtprotoServerRevokeAppPassword {
    public static let typeIdentifier = "com.atproto.server.revokeAppPassword"
    public struct Input: ATProtocolCodable {
        public let name: String

        // Standard public initializer
        public init(name: String) {
            self.name = name
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Revoke an App Password by name.
    func revokeAppPassword(
        input: ComAtprotoServerRevokeAppPassword.Input,

        duringInitialSetup: Bool = false
    ) async throws -> Int {
        let endpoint = "/com.atproto.server.revokeAppPassword"

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
