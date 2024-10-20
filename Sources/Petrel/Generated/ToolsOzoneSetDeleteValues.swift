import Foundation
import ZippyJSON

// lexicon: 1, id: tools.ozone.set.deleteValues

public enum ToolsOzoneSetDeleteValues {
    public static let typeIdentifier = "tools.ozone.set.deleteValues"
    public struct Input: ATProtocolCodable {
        public let name: String
        public let values: [String]

        // Standard public initializer
        public init(name: String, values: [String]) {
            self.name = name
            self.values = values
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
    /// Delete values from a specific set. Attempting to delete values that are not in the set will not result in an error
    func deleteValues(
        input: ToolsOzoneSetDeleteValues.Input

    ) async throws -> Int {
        let endpoint = "tools.ozone.set.deleteValues"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
    }
}
