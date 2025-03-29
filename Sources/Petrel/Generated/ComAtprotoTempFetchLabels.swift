import Foundation

// lexicon: 1, id: com.atproto.temp.fetchLabels

public enum ComAtprotoTempFetchLabels {
    public static let typeIdentifier = "com.atproto.temp.fetchLabels"
    public struct Parameters: Parametrizable {
        public let since: Int?
        public let limit: Int?

        public init(
            since: Int? = nil,
            limit: Int? = nil
        ) {
            self.since = since
            self.limit = limit
        }
    }

    public struct Output: ATProtocolCodable {
        public let labels: [ComAtprotoLabelDefs.Label]

        // Standard public initializer
        public init(
            labels: [ComAtprotoLabelDefs.Label]

        ) {
            self.labels = labels
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            labels = try container.decode([ComAtprotoLabelDefs.Label].self, forKey: .labels)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(labels, forKey: .labels)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            let labelsValue = try (labels as? DAGCBOREncodable)?.toCBORValue() ?? labels
            map = map.adding(key: "labels", value: labelsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case labels
        }
    }
}

public extension ATProtoClient.Com.Atproto.Temp {
    /// DEPRECATED: use queryLabels or subscribeLabels instead -- Fetch all labels from a labeler created after a certain date.
    func fetchLabels(input: ComAtprotoTempFetchLabels.Parameters) async throws -> (responseCode: Int, data: ComAtprotoTempFetchLabels.Output?) {
        let endpoint = "com.atproto.temp.fetchLabels"

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
        let decodedData = try? decoder.decode(ComAtprotoTempFetchLabels.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
