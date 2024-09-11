import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.admin.updateAccountEmail

public enum ComAtprotoAdminUpdateAccountEmail {
    public static let typeIdentifier = "com.atproto.admin.updateAccountEmail"
    public struct Input: ATProtocolCodable {
        public let account: String
        public let email: String

        // Standard public initializer
        public init(account: String, email: String) {
            self.account = account
            self.email = email
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    /// Administrative action to update an account's email.
    func updateAccountEmail(
        input: ComAtprotoAdminUpdateAccountEmail.Input,

        duringInitialSetup: Bool = false
    ) async throws -> Int {
        let endpoint = "/com.atproto.admin.updateAccountEmail"

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
