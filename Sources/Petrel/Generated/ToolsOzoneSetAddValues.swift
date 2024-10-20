import Foundation
import ZippyJSON

// lexicon: 1, id: tools.ozone.set.addValues

public enum ToolsOzoneSetAddValues {
    public static let typeIdentifier = "tools.ozone.set.addValues"
    public struct Input: ATProtocolCodable {
        public let name: String
        public let values: [String]

        // Standard public initializer
        public init(name: String, values: [String]) {
            self.name = name
            self.values = values
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Set {
    /// Add values to a specific set. Attempting to add values to a set that does not exist will result in an error.
    func addValues(
        input: ToolsOzoneSetAddValues.Input

    ) async throws -> Int {
        let endpoint = "tools.ozone.set.addValues"

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
