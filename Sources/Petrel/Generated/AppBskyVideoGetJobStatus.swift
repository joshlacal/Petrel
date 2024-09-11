import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.video.getJobStatus

public enum AppBskyVideoGetJobStatus {
    public static let typeIdentifier = "app.bsky.video.getJobStatus"
    public struct Parameters: Parametrizable {
        public let jobId: String

        public init(
            jobId: String
        ) {
            self.jobId = jobId
        }
    }

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
    /// Get status details for a video processing job.
    func getJobStatus(input: AppBskyVideoGetJobStatus.Parameters) async throws -> (responseCode: Int, data: AppBskyVideoGetJobStatus.Output?) {
        let endpoint = "/app.bsky.video.getJobStatus"

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
        let decodedData = try? decoder.decode(AppBskyVideoGetJobStatus.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
