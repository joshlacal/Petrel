import Foundation

// lexicon: 1, id: com.atproto.identity.resolveHandle

public enum ComAtprotoIdentityResolveHandle {
    public static let typeIdentifier = "com.atproto.identity.resolveHandle"
    public struct Parameters: Parametrizable {
        public let handle: Handle

        public init(
            handle: Handle
        ) {
            self.handle = handle
        }
    }

    public struct Output: ATProtocolCodable {
        public let did: DID

        // Standard public initializer
        public init(
            did: DID

        ) {
            self.did = did
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            did = try container.decode(DID.self, forKey: .did)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(did, forKey: .did)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case did
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case handleNotFound = "HandleNotFound.The resolution process confirmed that the handle does not resolve to any DID."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Identity {
    // MARK: - resolveHandle

    /// Resolves an atproto handle (hostname) to a DID. Does not necessarily bi-directionally verify against the the DID document.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func resolveHandle(input: ComAtprotoIdentityResolveHandle.Parameters) async throws -> (responseCode: Int, data: ComAtprotoIdentityResolveHandle.Output?) {
        let endpoint = "com.atproto.identity.resolveHandle"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.identity.resolveHandle")
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
                let decodedData = try decoder.decode(ComAtprotoIdentityResolveHandle.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.identity.resolveHandle: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
