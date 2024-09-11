import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.admin.getAccountInfos

public enum ComAtprotoAdminGetAccountInfos {
    public static let typeIdentifier = "com.atproto.admin.getAccountInfos"
    public struct Parameters: Parametrizable {
        public let dids: [String]

        public init(
            dids: [String]
        ) {
            self.dids = dids
        }
    }

    public struct Output: ATProtocolCodable {
        public let infos: [ComAtprotoAdminDefs.AccountView]

        // Standard public initializer
        public init(
            infos: [ComAtprotoAdminDefs.AccountView]
        ) {
            self.infos = infos
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    /// Get details about some accounts.
    func getAccountInfos(input: ComAtprotoAdminGetAccountInfos.Parameters) async throws -> (responseCode: Int, data: ComAtprotoAdminGetAccountInfos.Output?) {
        let endpoint = "/com.atproto.admin.getAccountInfos"

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
        let decodedData = try? decoder.decode(ComAtprotoAdminGetAccountInfos.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
