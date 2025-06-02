import Foundation



// lexicon: 1, id: app.bsky.video.uploadVideo


public struct AppBskyVideoUploadVideo { 

    public static let typeIdentifier = "app.bsky.video.uploadVideo"
    
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
            
            
            self.jobStatus = try container.decode(AppBskyVideoDefs.JobStatus.self, forKey: .jobStatus)
            
            
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

extension ATProtoClient.App.Bsky.Video {
    // MARK: - uploadVideo

    /// Upload a video to be processed then stored on the PDS.
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func uploadVideo(
        
    ) async throws -> (responseCode: Int, data: AppBskyVideoUploadVideo.Output?) {
        let endpoint = "app.bsky.video.uploadVideo"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "video/mp4"
        
        
        
        headers["Accept"] = "application/json"
        

        let requestData: Data? = nil
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
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
                           
