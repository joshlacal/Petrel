import Foundation

// lexicon: 1, id: com.atproto.server.deleteAccount

public enum ComAtprotoServerDeleteAccount {
    public static let typeIdentifier = "com.atproto.server.deleteAccount"
    public struct Input: ATProtocolCodable {
        public let did: String
        public let password: String
        public let token: String

        // Standard public initializer
        public init(did: String, password: String, token: String) {
            self.did = did
            self.password = password
            self.token = token
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case expiredToken = "ExpiredToken."
        case invalidToken = "InvalidToken."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Delete an actor's account with a token and password. Can only be called after requesting a deletion token. Requires auth.
    func deleteAccount(
        input: ComAtprotoServerDeleteAccount.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.server.deleteAccount"

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
