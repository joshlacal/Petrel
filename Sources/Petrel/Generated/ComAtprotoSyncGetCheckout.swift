import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.sync.getCheckout

public enum ComAtprotoSyncGetCheckout {
    public static let typeIdentifier = "com.atproto.sync.getCheckout"
    public struct Parameters: Parametrizable {
        public let did: String

        public init(
            did: String
        ) {
            self.did = did
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
}

public extension ATProtoClient.Com.Atproto.Sync {
    /// DEPRECATED - please use com.atproto.sync.getRepo instead
    func getCheckout(input: ComAtprotoSyncGetCheckout.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetCheckout.Output?) {
        let endpoint = "com.atproto.sync.getCheckout"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/vnd.ipld.car"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/vnd.ipld.car", actual: "nil")
        }

        if !contentType.lowercased().contains("application/vnd.ipld.car") {
            throw NetworkError.invalidContentType(expected: "application/vnd.ipld.car", actual: contentType)
        }

        // Data decoding and validation

        let decodedData = ComAtprotoSyncGetCheckout.Output(data: responseData)

        return (responseCode, decodedData)
    }
}
