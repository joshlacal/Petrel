import Foundation

// lexicon: 1, id: com.atproto.temp.dereferenceScope

public enum ComAtprotoTempDereferenceScope {
    public static let typeIdentifier = "com.atproto.temp.dereferenceScope"
    public struct Parameters: Parametrizable {
        public let scope: String

        public init(
            scope: String
        ) {
            self.scope = scope
        }
    }

    public struct Output: ATProtocolCodable {
        public let scope: String

        // Standard public initializer
        public init(
            scope: String

        ) {
            self.scope = scope
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            scope = try container.decode(String.self, forKey: .scope)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(scope, forKey: .scope)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let scopeValue = try scope.toCBORValue()
            map = map.adding(key: "scope", value: scopeValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case scope
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case invalidScopeReference = "InvalidScopeReference.An invalid scope reference was provided."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Temp {
    // MARK: - dereferenceScope

    /// Allows finding the oauth permission scope from a reference
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func dereferenceScope(input: ComAtprotoTempDereferenceScope.Parameters) async throws -> (responseCode: Int, data: ComAtprotoTempDereferenceScope.Output?) {
        let endpoint = "com.atproto.temp.dereferenceScope"

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

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoTempDereferenceScope.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
