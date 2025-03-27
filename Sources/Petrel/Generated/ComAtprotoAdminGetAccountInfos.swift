import Foundation

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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            infos = try container.decode([ComAtprotoAdminDefs.AccountView].self, forKey: .infos)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(infos, forKey: .infos)
        }

        private enum CodingKeys: String, CodingKey {
            case infos
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    /// Get details about some accounts.
    func getAccountInfos(input: ComAtprotoAdminGetAccountInfos.Parameters) async throws -> (responseCode: Int, data: ComAtprotoAdminGetAccountInfos.Output?) {
        let endpoint = "com.atproto.admin.getAccountInfos"

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
        let decodedData = try? decoder.decode(ComAtprotoAdminGetAccountInfos.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
