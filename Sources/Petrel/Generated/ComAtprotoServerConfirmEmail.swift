import Foundation

// lexicon: 1, id: com.atproto.server.confirmEmail

public enum ComAtprotoServerConfirmEmail {
    public static let typeIdentifier = "com.atproto.server.confirmEmail"
    public struct Input: ATProtocolCodable {
        public let email: String
        public let token: String

        // Standard public initializer
        public init(email: String, token: String) {
            self.email = email
            self.token = token
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case accountNotFound = "AccountNotFound."
        case expiredToken = "ExpiredToken."
        case invalidToken = "InvalidToken."
        case invalidEmail = "InvalidEmail."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Confirm an email using a token from com.atproto.server.requestEmailConfirmation.
    func confirmEmail(
        input: ComAtprotoServerConfirmEmail.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.server.confirmEmail"

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
