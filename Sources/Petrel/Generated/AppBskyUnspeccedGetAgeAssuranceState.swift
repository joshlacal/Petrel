import Foundation



// lexicon: 1, id: app.bsky.unspecced.getAgeAssuranceState


public struct AppBskyUnspeccedGetAgeAssuranceState { 

    public static let typeIdentifier = "app.bsky.unspecced.getAgeAssuranceState"
    public typealias Output = AppBskyUnspeccedDefs.AgeAssuranceState
    



}


extension ATProtoClient.App.Bsky.Unspecced {
    // MARK: - getAgeAssuranceState

    /// Returns the current state of the age assurance process for an account. This is used to check if the user has completed age assurance or if further action is required.
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getAgeAssuranceState() async throws -> (responseCode: Int, data: AppBskyUnspeccedGetAgeAssuranceState.Output?) {
        let endpoint = "app.bsky.unspecced.getAgeAssuranceState"

        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.unspecced.getAgeAssuranceState")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200...299).contains(responseCode) {
            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(AppBskyUnspeccedGetAgeAssuranceState.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.unspecced.getAgeAssuranceState: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           

