import Foundation

// lexicon: 1, id: tools.ozone.set.querySets

public enum ToolsOzoneSetQuerySets {
    public static let typeIdentifier = "tools.ozone.set.querySets"
    public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?
        public let namePrefix: String?
        public let sortBy: String?
        public let sortDirection: String?

        public init(
            limit: Int? = nil,
            cursor: String? = nil,
            namePrefix: String? = nil,
            sortBy: String? = nil,
            sortDirection: String? = nil
        ) {
            self.limit = limit
            self.cursor = cursor
            self.namePrefix = namePrefix
            self.sortBy = sortBy
            self.sortDirection = sortDirection
        }
    }

    public struct Output: ATProtocolCodable {
        public let sets: [ToolsOzoneSetDefs.SetView]

        public let cursor: String?

        // Standard public initializer
        public init(
            sets: [ToolsOzoneSetDefs.SetView],

            cursor: String? = nil

        ) {
            self.sets = sets

            self.cursor = cursor
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            sets = try container.decode([ToolsOzoneSetDefs.SetView].self, forKey: .sets)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(sets, forKey: .sets)

            if let value = cursor {
                try container.encode(value, forKey: .cursor)
            }
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            let setsValue = try (sets as? DAGCBOREncodable)?.toCBORValue() ?? sets
            map = map.adding(key: "sets", value: setsValue)

            if let value = cursor {
                let cursorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cursor", value: cursorValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case sets
            case cursor
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Set {
    /// Query available sets
    func querySets(input: ToolsOzoneSetQuerySets.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneSetQuerySets.Output?) {
        let endpoint = "tools.ozone.set.querySets"

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
        let decodedData = try? decoder.decode(ToolsOzoneSetQuerySets.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
