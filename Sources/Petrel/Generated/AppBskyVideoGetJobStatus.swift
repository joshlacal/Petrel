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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let jobStatusValue = try jobStatus.toCBORValue()
            map = map.adding(key: "jobStatus", value: jobStatusValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case jobStatus
        }
    }
}

public extension ATProtoClient.App.Bsky.Video {
    // MARK: - getJobStatus

    /// Get status details for a video processing job.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getJobStatus(input: AppBskyVideoGetJobStatus.Parameters) async throws -> (responseCode: Int, data: AppBskyVideoGetJobStatus.Output?) {
        let endpoint = "app.bsky.video.getJobStatus"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)

        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(AppBskyVideoGetJobStatus.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.video.getJobStatus: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
