import Foundation

// lexicon: 1, id: com.atproto.sync.requestCrawl

public enum ComAtprotoSyncRequestCrawl {
    public static let typeIdentifier = "com.atproto.sync.requestCrawl"
    public struct Input: ATProtocolCodable {
        public let hostname: String

        // Standard public initializer
        public init(hostname: String) {
            self.hostname = hostname
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            hostname = try container.decode(String.self, forKey: .hostname)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(hostname, forKey: .hostname)
        }

        private enum CodingKeys: String, CodingKey {
            case hostname
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let hostnameValue = try hostname.toCBORValue()
            map = map.adding(key: "hostname", value: hostnameValue)

            return map
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case hostBanned = "HostBanned."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Sync {
    // MARK: - requestCrawl

    /// Request a service to persistently crawl hosted repos. Expected use is new PDS instances declaring their existence to Relays. Does not require auth.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func requestCrawl(
        input: ComAtprotoSyncRequestCrawl.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.sync.requestCrawl"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkService.performRequest(urlRequest)

        let responseCode = response.statusCode
        return responseCode
    }
}
