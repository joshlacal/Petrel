import Foundation

// lexicon: 1, id: tools.ozone.set.upsertSet

public enum ToolsOzoneSetUpsertSet {
    public static let typeIdentifier = "tools.ozone.set.upsertSet"
    public struct Input: ATProtocolCodable {
        public let data: ToolsOzoneSetDefs.Set

        // Standard public initializer
        public init(data: ToolsOzoneSetDefs.Set) {
            self.data = data
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            data = try container.decode(ToolsOzoneSetDefs.Set.self, forKey: .data)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(data, forKey: .data)
        }

        private enum CodingKeys: String, CodingKey {
            case data
        }
    }

    public typealias Output = ToolsOzoneSetDefs.SetView
}

public extension ATProtoClient.Tools.Ozone.Set {
    /// Create or update set metadata
    func upsertSet(
        input: ToolsOzoneSetUpsertSet.Input

    ) async throws -> (responseCode: Int, data: ToolsOzoneSetUpsertSet.Output?) {
        let endpoint = "tools.ozone.set.upsertSet"

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
        let decodedData = try? decoder.decode(ToolsOzoneSetUpsertSet.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
