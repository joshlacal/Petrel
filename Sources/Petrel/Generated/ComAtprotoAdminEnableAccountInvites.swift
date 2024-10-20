import Foundation
import ZippyJSON

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
        input: ComAtprotoAdminEnableAccountInvites.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.admin.enableAccountInvites"

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
