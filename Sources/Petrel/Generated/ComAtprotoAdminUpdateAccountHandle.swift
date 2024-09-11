import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.admin.updateAccountHandle

public enum ComAtprotoAdminUpdateAccountHandle {
    public static let typeIdentifier = "com.atproto.admin.updateAccountHandle"
    public struct Input: ATProtocolCodable {
        public let did: String
        public let handle: String

        // Standard public initializer
        public init(did: String, handle: String) {
            self.did = did
            self.handle = handle
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    /// Administrative action to update an account's handle.
    func updateAccountHandle(
        input: ComAtprotoAdminUpdateAccountHandle.Input,

        duringInitialSetup: Bool = false
    ) async throws -> Int {
        let endpoint = "/com.atproto.admin.updateAccountHandle"

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
