import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.admin.disableAccountInvites

public enum ComAtprotoAdminDisableAccountInvites {
    public static let typeIdentifier = "com.atproto.admin.disableAccountInvites"
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
    /// Disable an account from receiving new invite codes, but does not invalidate existing codes.
    func disableAccountInvites(
        input: ComAtprotoAdminDisableAccountInvites.Input,

        duringInitialSetup: Bool = false
    ) async throws -> Int {
        let endpoint = "/com.atproto.admin.disableAccountInvites"

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
