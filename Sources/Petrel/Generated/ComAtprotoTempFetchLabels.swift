import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.temp.fetchLabels

public enum ComAtprotoTempFetchLabels {
    public static let typeIdentifier = "com.atproto.temp.fetchLabels"
    public struct Parameters: Parametrizable {
        public let since: Int?
        public let limit: Int?

        public init(
            since: Int? = nil,
            limit: Int? = nil
        ) {
            self.since = since
            self.limit = limit
        }
    }

    public struct Output: ATProtocolCodable {
        public let labels: [ComAtprotoLabelDefs.Label]

        // Standard public initializer
        public init(
            labels: [ComAtprotoLabelDefs.Label]
        ) {
            self.labels = labels
        }
    }
}

public extension ATProtoClient.Com.Atproto.Temp {
    /// DEPRECATED: use queryLabels or subscribeLabels instead -- Fetch all labels from a labeler created after a certain date.
    func fetchLabels(input: ComAtprotoTempFetchLabels.Parameters) async throws -> (responseCode: Int, data: ComAtprotoTempFetchLabels.Output?) {
        let endpoint = "/com.atproto.temp.fetchLabels"

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
        let decodedData = try? decoder.decode(ComAtprotoTempFetchLabels.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
