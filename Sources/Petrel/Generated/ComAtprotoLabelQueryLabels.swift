import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.label.queryLabels

public enum ComAtprotoLabelQueryLabels {
    public static let typeIdentifier = "com.atproto.label.queryLabels"
    public struct Parameters: Parametrizable {
        public let uriPatterns: [String]
        public let sources: [String]?
        public let limit: Int?
        public let cursor: String?

        public init(
            uriPatterns: [String],
            sources: [String]? = nil,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.uriPatterns = uriPatterns
            self.sources = sources
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let labels: [ComAtprotoLabelDefs.Label]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            labels: [ComAtprotoLabelDefs.Label]
        ) {
            self.cursor = cursor

            self.labels = labels
        }
    }
}

public extension ATProtoClient.Com.Atproto.Label {
    /// Find labels relevant to the provided AT-URI patterns. Public endpoint for moderation services, though may return different or additional results with auth.
    func queryLabels(input: ComAtprotoLabelQueryLabels.Parameters) async throws -> (responseCode: Int, data: ComAtprotoLabelQueryLabels.Output?) {
        let endpoint = "/com.atproto.label.queryLabels"

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
        let decodedData = try? decoder.decode(ComAtprotoLabelQueryLabels.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
