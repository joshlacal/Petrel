import Foundation

// lexicon: 1, id: com.atproto.lexicon.resolveLexicon

public enum ComAtprotoLexiconResolveLexicon {
    public static let typeIdentifier = "com.atproto.lexicon.resolveLexicon"
    public struct Parameters: Parametrizable {
        public let nsid: NSID

        public init(
            nsid: NSID
        ) {
            self.nsid = nsid
        }
    }

    public struct Output: ATProtocolCodable {
        public let cid: CID

        public let schema: ComAtprotoLexiconSchema.Main

        public let uri: ATProtocolURI

        // Standard public initializer
        public init(
            cid: CID,

            schema: ComAtprotoLexiconSchema.Main,

            uri: ATProtocolURI

        ) {
            self.cid = cid

            self.schema = schema

            self.uri = uri
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cid = try container.decode(CID.self, forKey: .cid)

            schema = try container.decode(ComAtprotoLexiconSchema.Main.self, forKey: .schema)

            uri = try container.decode(ATProtocolURI.self, forKey: .uri)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(cid, forKey: .cid)

            try container.encode(schema, forKey: .schema)

            try container.encode(uri, forKey: .uri)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)

            let schemaValue = try schema.toCBORValue()
            map = map.adding(key: "schema", value: schemaValue)

            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cid
            case schema
            case uri
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case lexiconNotFound = "LexiconNotFound.No lexicon was resolved for the NSID."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Lexicon {
    // MARK: - resolveLexicon

    /// Resolves an atproto lexicon (NSID) to a schema.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func resolveLexicon(input: ComAtprotoLexiconResolveLexicon.Parameters) async throws -> (responseCode: Int, data: ComAtprotoLexiconResolveLexicon.Output?) {
        let endpoint = "com.atproto.lexicon.resolveLexicon"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.lexicon.resolveLexicon")
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
                let decodedData = try decoder.decode(ComAtprotoLexiconResolveLexicon.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.lexicon.resolveLexicon: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
