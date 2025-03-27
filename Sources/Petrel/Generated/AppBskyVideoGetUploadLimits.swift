import Foundation

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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            canUpload = try container.decode(Bool.self, forKey: .canUpload)

            remainingDailyVideos = try container.decodeIfPresent(Int.self, forKey: .remainingDailyVideos)

            remainingDailyBytes = try container.decodeIfPresent(Int.self, forKey: .remainingDailyBytes)

            message = try container.decodeIfPresent(String.self, forKey: .message)

            error = try container.decodeIfPresent(String.self, forKey: .error)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(canUpload, forKey: .canUpload)

            if let value = remainingDailyVideos {
                try container.encode(value, forKey: .remainingDailyVideos)
            }

            if let value = remainingDailyBytes {
                try container.encode(value, forKey: .remainingDailyBytes)
            }

            if let value = message {
                try container.encode(value, forKey: .message)
            }

            if let value = error {
                try container.encode(value, forKey: .error)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case canUpload
            case remainingDailyVideos
            case remainingDailyBytes
            case message
            case error
        }
    }
}

public extension ATProtoClient.App.Bsky.Video {
    /// Get video upload limits for the authenticated user.
    func getUploadLimits() async throws -> (responseCode: Int, data: AppBskyVideoGetUploadLimits.Output?) {
        let endpoint = "app.bsky.video.getUploadLimits"

        let queryItems: [URLQueryItem]? = nil

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
        let decodedData = try? decoder.decode(AppBskyVideoGetUploadLimits.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
