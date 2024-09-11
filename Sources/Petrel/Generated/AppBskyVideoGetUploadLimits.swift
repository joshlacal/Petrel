import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.video.getUploadLimits

public enum AppBskyVideoGetUploadLimits {
    public static let typeIdentifier = "app.bsky.video.getUploadLimits"

    public struct Output: ATProtocolCodable {
        public let canUpload: Bool

        public let remainingDailyVideos: Int?

        public let remainingDailyBytes: Int?

        public let message: String?

        public let error: String?

        // Standard public initializer
        public init(
            canUpload: Bool,

            remainingDailyVideos: Int? = nil,

            remainingDailyBytes: Int? = nil,

            message: String? = nil,

            error: String? = nil
        ) {
            self.canUpload = canUpload

            self.remainingDailyVideos = remainingDailyVideos

            self.remainingDailyBytes = remainingDailyBytes

            self.message = message

            self.error = error
        }
    }
}

public extension ATProtoClient.App.Bsky.Video {
    /// Get video upload limits for the authenticated user.
    func getUploadLimits() async throws -> (responseCode: Int, data: AppBskyVideoGetUploadLimits.Output?) {
        let endpoint = "/app.bsky.video.getUploadLimits"

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
        let decodedData = try? decoder.decode(AppBskyVideoGetUploadLimits.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
