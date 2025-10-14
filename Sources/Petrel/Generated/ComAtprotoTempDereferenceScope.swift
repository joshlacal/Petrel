import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.temp.dereferenceScope")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
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
                let decodedData = try decoder.decode(ComAtprotoTempDereferenceScope.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.temp.dereferenceScope: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
