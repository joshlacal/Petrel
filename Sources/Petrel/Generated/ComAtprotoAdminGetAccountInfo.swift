import Foundation

// lexicon: 1, id: com.atproto.admin.getAccountInfo

public enum ComAtprotoAdminGetAccountInfo {
    public static let typeIdentifier = "com.atproto.admin.getAccountInfo"
    public struct Parameters: Parametrizable {
        public let did: String

        public init(
            did: String
        ) {
            self.did = did
        }
    }

    public typealias Output = ComAtprotoAdminDefs.AccountView
}

public extension ATProtoClient.Com.Atproto.Admin {
    /// Get details about an account.
    func getAccountInfo(input: ComAtprotoAdminGetAccountInfo.Parameters) async throws -> (responseCode: Int, data: ComAtprotoAdminGetAccountInfo.Output?) {
        let endpoint = "com.atproto.admin.getAccountInfo"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoAdminGetAccountInfo.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
