import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.sync.getHead

public enum ComAtprotoSyncGetHead {
    public static let typeIdentifier = "com.atproto.sync.getHead"
    public struct Parameters: Parametrizable {
        public let did: String

        public init(
            did: String
        ) {
            self.did = did
        }
    }

    public struct Output: ATProtocolCodable {
        public let root: String

        // Standard public initializer
        public init(
            root: String
        ) {
            self.root = root
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case headNotFound = "HeadNotFound."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Sync {
    /// DEPRECATED - please use com.atproto.sync.getLatestCommit instead
    func getHead(input: ComAtprotoSyncGetHead.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetHead.Output?) {
        let endpoint = "/com.atproto.sync.getHead"

        let queryItems = input.asQueryItems()
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: false)
        let responseCode = response.statusCode

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoSyncGetHead.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
