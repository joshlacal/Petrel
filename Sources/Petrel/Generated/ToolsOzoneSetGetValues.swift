import Foundation
import ZippyJSON

// lexicon: 1, id: tools.ozone.set.getValues

public enum ToolsOzoneSetGetValues {
    public static let typeIdentifier = "tools.ozone.set.getValues"
    public struct Parameters: Parametrizable {
        public let name: String
        public let limit: Int?
        public let cursor: String?

        public init(
            name: String,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.name = name
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let set: ToolsOzoneSetDefs.SetView

        public let values: [String]

        public let cursor: String?

        // Standard public initializer
        public init(
            set: ToolsOzoneSetDefs.SetView,

            values: [String],

            cursor: String? = nil

        ) {
            self.set = set

            self.values = values

            self.cursor = cursor
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case setNotFound = "SetNotFound.set with the given name does not exist"
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Set {
    /// Get a specific set and its values
    func getValues(input: ToolsOzoneSetGetValues.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneSetGetValues.Output?) {
        let endpoint = "tools.ozone.set.getValues"

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
        let decodedData = try? decoder.decode(ToolsOzoneSetGetValues.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
