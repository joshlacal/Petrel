import Foundation

// lexicon: 1, id: com.atproto.admin.updateAccountPassword

public enum ComAtprotoAdminUpdateAccountPassword {
    public static let typeIdentifier = "com.atproto.admin.updateAccountPassword"
    public struct Input: ATProtocolCodable {
        public let did: String
        public let password: String

        // Standard public initializer
        public init(did: String, password: String) {
            self.did = did
            self.password = password
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    /// Update the password for a user account as an administrator.
    func updateAccountPassword(
        input: ComAtprotoAdminUpdateAccountPassword.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.admin.updateAccountPassword"

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
