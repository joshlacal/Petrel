import Foundation

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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            jobStatus = try container.decode(AppBskyVideoDefs.JobStatus.self, forKey: .jobStatus)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(jobStatus, forKey: .jobStatus)
        }

        private enum CodingKeys: String, CodingKey {
            case jobStatus
        }
    }
}

public extension ATProtoClient.App.Bsky.Video {
    /// Get status details for a video processing job.
    func getJobStatus(input: AppBskyVideoGetJobStatus.Parameters) async throws -> (responseCode: Int, data: AppBskyVideoGetJobStatus.Output?) {
        let endpoint = "app.bsky.video.getJobStatus"

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

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyVideoGetJobStatus.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
