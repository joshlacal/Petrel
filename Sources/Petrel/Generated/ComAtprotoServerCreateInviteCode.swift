import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.server.createInviteCode

public enum ComAtprotoServerCreateInviteCode {
    public static let typeIdentifier = "com.atproto.server.createInviteCode"
    public struct Input: ATProtocolCodable {
        public let useCount: Int
        public let forAccount: String?

        // Standard public initializer
        public init(useCount: Int, forAccount: String? = nil) {
            self.useCount = useCount
            self.forAccount = forAccount
        }
    }

    public struct Output: ATProtocolCodable {
        public let code: String

        // Standard public initializer
        public init(
            code: String
        ) {
            self.code = code
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Create an invite code.
    func createInviteCode(
        input: ComAtprotoServerCreateInviteCode.Input,

        duringInitialSetup: Bool = false
    ) async throws -> (responseCode: Int, data: ComAtprotoServerCreateInviteCode.Output?) {
        let endpoint = "/com.atproto.server.createInviteCode"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        let decodedData = try? ZippyJSONDecoder().decode(ComAtprotoServerCreateInviteCode.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
