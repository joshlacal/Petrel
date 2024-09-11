import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.video.uploadVideo

public enum AppBskyVideoUploadVideo {
    public static let typeIdentifier = "app.bsky.video.uploadVideo"

    public struct Output: ATProtocolCodable {
        public let jobStatus: AppBskyVideoDefs.JobStatus

        // Standard public initializer
        public init(
            jobStatus: AppBskyVideoDefs.JobStatus
        ) {
            self.jobStatus = jobStatus
        }
    }
}

public extension ATProtoClient.App.Bsky.Video {
    /// Upload a video to be processed then stored on the PDS.
    func uploadVideo(
        duringInitialSetup: Bool = false
    ) async throws -> (responseCode: Int, data: AppBskyVideoUploadVideo.Output?) {
        let endpoint = "/app.bsky.video.uploadVideo"

        let requestData: Data? = nil
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        let decodedData = try? ZippyJSONDecoder().decode(AppBskyVideoUploadVideo.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
