import Foundation

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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            useCount = try container.decode(Int.self, forKey: .useCount)

            forAccount = try container.decodeIfPresent(String.self, forKey: .forAccount)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(useCount, forKey: .useCount)

            if let value = forAccount {
                try container.encode(value, forKey: .forAccount)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case useCount
            case forAccount
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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            code = try container.decode(String.self, forKey: .code)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(code, forKey: .code)
        }

        private enum CodingKeys: String, CodingKey {
            case code
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Create an invite code.
    func createInviteCode(
        input: ComAtprotoServerCreateInviteCode.Input

    ) async throws -> (responseCode: Int, data: ComAtprotoServerCreateInviteCode.Output?) {
        let endpoint = "com.atproto.server.createInviteCode"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
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
        let decodedData = try? decoder.decode(ComAtprotoServerCreateInviteCode.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
