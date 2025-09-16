import Foundation

// lexicon: 1, id: com.atproto.admin.getAccountInfo

public enum ComAtprotoAdminGetAccountInfo {
    public static let typeIdentifier = "com.atproto.admin.getAccountInfo"
    public struct Parameters: Parametrizable {
        public let did: DID

        public init(
            did: DID
        ) {
            self.did = did
        }
    }

    public typealias Output = ComAtprotoAdminDefs.AccountView
}

public extension ATProtoClient.Com.Atproto.Admin {
    // MARK: - getAccountInfo

    /// Get details about an account.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getAccountInfo(input: ComAtprotoAdminGetAccountInfo.Parameters) async throws -> (responseCode: Int, data: ComAtprotoAdminGetAccountInfo.Output?) {
        let endpoint = "com.atproto.admin.getAccountInfo"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)

        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ComAtprotoAdminGetAccountInfo.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.admin.getAccountInfo: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
