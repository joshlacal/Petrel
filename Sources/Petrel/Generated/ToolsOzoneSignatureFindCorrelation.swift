import Foundation
import ZippyJSON

// lexicon: 1, id: tools.ozone.signature.findCorrelation

public enum ToolsOzoneSignatureFindCorrelation {
    public static let typeIdentifier = "tools.ozone.signature.findCorrelation"
    public struct Parameters: Parametrizable {
        public let dids: [String]

        public init(
            dids: [String]
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

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneSignatureFindCorrelation.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
