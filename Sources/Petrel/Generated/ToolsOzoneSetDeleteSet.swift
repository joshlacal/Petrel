import Foundation
import ZippyJSON

// lexicon: 1, id: tools.ozone.set.deleteSet

public enum ToolsOzoneSetDeleteSet {
    public static let typeIdentifier = "tools.ozone.set.deleteSet"
    public struct Input: ATProtocolCodable {
        public let name: String

        // Standard public initializer
        public init(name: String) {
            self.name = name
        }
    }

    public struct Output: ATProtocolCodable {
        public let data: Data

        // Standard public initializer
        public init(
            data: Data

        ) {
            self.data = data
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
    /// Delete an entire set. Attempting to delete a set that does not exist will result in an error.
    func deleteSet(
        input: ToolsOzoneSetDeleteSet.Input

    ) async throws -> (responseCode: Int, data: ToolsOzoneSetDeleteSet.Output?) {
        let endpoint = "tools.ozone.set.deleteSet"

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

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneSetDeleteSet.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
