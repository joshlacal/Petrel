import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.admin.enableAccountInvites

public enum ComAtprotoAdminEnableAccountInvites {
    public static let typeIdentifier = "com.atproto.admin.enableAccountInvites"
    public struct Input: ATProtocolCodable {
        public let account: String
        public let note: String?

        // Standard public initializer
        public init(account: String, note: String? = nil) {
            self.account = account
            self.note = note
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    /// Re-enable an account's ability to receive invite codes.
    func enableAccountInvites(
        input: ComAtprotoAdminEnableAccountInvites.Input,

        duringInitialSetup: Bool = false
    ) async throws -> Int {
        let endpoint = "/com.atproto.admin.enableAccountInvites"

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
