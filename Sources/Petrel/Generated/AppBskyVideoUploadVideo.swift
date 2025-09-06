import Foundation

// lexicon: 1, id: app.bsky.video.uploadVideo

public enum AppBskyVideoUploadVideo {
    public static let typeIdentifier = "app.bsky.video.uploadVideo"
    public struct Input: ATProtocolCodable {
        public let data: Data

        // Standard public initializer
        public init(data: Data) {
            self.data = data
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            data = try container.decode(Data.self, forKey: .data)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(data, forKey: .data)
        }

        private enum CodingKeys: String, CodingKey {
            case data
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let dataValue = try data.toCBORValue()
            map = map.adding(key: "data", value: dataValue)

            return map
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
    // MARK: - uploadVideo

    /// Upload a video to be processed then stored on the PDS.
    ///
    /// - Parameter data: The binary data to upload
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func uploadVideo(
        data: Data

    ) async throws -> (responseCode: Int, data: AppBskyVideoUploadVideo.Output?) {
        let endpoint = "app.bsky.video.uploadVideo"

        let dataToUpload = data
        var headers: [String: String] = [
            "Content-Type": "video/mp4",
            "Content-Length": "\(dataToUpload.count)",
        ]

        headers["Accept"] = "application/json"

        let requestData: Data? = nil
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: dataToUpload,
            queryItems: nil
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)

        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyVideoUploadVideo.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
