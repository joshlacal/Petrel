import Foundation

// lexicon: 1, id: tools.ozone.signature.findCorrelation

public enum ToolsOzoneSignatureFindCorrelation {
    public static let typeIdentifier = "tools.ozone.signature.findCorrelation"
    public struct Parameters: Parametrizable {
        public let dids: [DID]

        public init(
            dids: [DID]
        ) {
            self.dids = dids
        }
    }

    public struct Output: ATProtocolCodable {
        public let details: [ToolsOzoneSignatureDefs.SigDetail]

        // Standard public initializer
        public init(
            details: [ToolsOzoneSignatureDefs.SigDetail]

        ) {
            self.details = details
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            details = try container.decode([ToolsOzoneSignatureDefs.SigDetail].self, forKey: .details)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(details, forKey: .details)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let detailsValue = try (details as? DAGCBOREncodable)?.toCBORValue() ?? details
            map = map.adding(key: "details", value: detailsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case details
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Signature {
    /// Find all correlated threat signatures between 2 or more accounts.
    func findCorrelation(input: ToolsOzoneSignatureFindCorrelation.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneSignatureFindCorrelation.Output?) {
        let endpoint = "tools.ozone.signature.findCorrelation"

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
        let decodedData = try? decoder.decode(ToolsOzoneSignatureFindCorrelation.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
