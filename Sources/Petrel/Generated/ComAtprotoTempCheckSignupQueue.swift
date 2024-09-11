import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.temp.checkSignupQueue

public enum ComAtprotoTempCheckSignupQueue {
    public static let typeIdentifier = "com.atproto.temp.checkSignupQueue"

    public struct Output: ATProtocolCodable {
        public let activated: Bool

        public let placeInQueue: Int?

        public let estimatedTimeMs: Int?

        // Standard public initializer
        public init(
            activated: Bool,

            placeInQueue: Int? = nil,

            estimatedTimeMs: Int? = nil
        ) {
            self.activated = activated

            self.placeInQueue = placeInQueue

            self.estimatedTimeMs = estimatedTimeMs
        }
    }
}

public extension ATProtoClient.Com.Atproto.Temp {
    /// Check accounts location in signup queue.
    func checkSignupQueue() async throws -> (responseCode: Int, data: ComAtprotoTempCheckSignupQueue.Output?) {
        let endpoint = "/com.atproto.temp.checkSignupQueue"

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: false)
        let responseCode = response.statusCode

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoTempCheckSignupQueue.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
