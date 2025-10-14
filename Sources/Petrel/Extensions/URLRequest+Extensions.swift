import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

extension URLRequest {
    func createNewRequestObject() -> URLRequest {
        var newRequest = URLRequest(url: url!)
        newRequest.httpMethod = httpMethod
        newRequest.httpBody = httpBody

        // Copy headers except authentication ones that need to be regenerated
        for (key, value) in allHTTPHeaderFields ?? [:] {
            if key != "Authorization" && key != "DPoP" {
                newRequest.setValue(value, forHTTPHeaderField: key)
            }
        }

        return newRequest
    }

    func createFreshRequestWithoutAuthHeaders() -> URLRequest {
        var newRequest = URLRequest(url: url!)
        newRequest.httpMethod = httpMethod
        newRequest.httpBody = httpBody

        // Copy all non-auth headers
        for (key, value) in allHTTPHeaderFields ?? [:] {
            if key != "Authorization" && key != "DPoP" {
                newRequest.setValue(value, forHTTPHeaderField: key)
            }
        }

        return newRequest
    }
}
