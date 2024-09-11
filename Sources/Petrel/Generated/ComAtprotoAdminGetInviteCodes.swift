import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.admin.getInviteCodes

public enum ComAtprotoAdminGetInviteCodes {
    public static let typeIdentifier = "com.atproto.admin.getInviteCodes"
    public struct Parameters: Parametrizable {
        public let sort: String?
        public let limit: Int?
        public let cursor: String?

        public init(
            sort: String? = nil,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.sort = sort
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let codes: [ComAtprotoServerDefs.InviteCode]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            codes: [ComAtprotoServerDefs.InviteCode]
        ) {
            self.cursor = cursor

            self.codes = codes
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    /// Get an admin view of invite codes.
    func getInviteCodes(input: ComAtprotoAdminGetInviteCodes.Parameters) async throws -> (responseCode: Int, data: ComAtprotoAdminGetInviteCodes.Output?) {
        let endpoint = "/com.atproto.admin.getInviteCodes"

        let queryItems = input.asQueryItems()
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: false)
        let responseCode = response.statusCode

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoAdminGetInviteCodes.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
