import Foundation

extension URLRequest {
  func createNewRequestObject() -> URLRequest {
    var newRequest = URLRequest(url: self.url!)
    newRequest.httpMethod = self.httpMethod
    newRequest.httpBody = self.httpBody

    // Copy headers except authentication ones that need to be regenerated
    for (key, value) in self.allHTTPHeaderFields ?? [:] {
      if key != "Authorization" && key != "DPoP" {
        newRequest.setValue(value, forHTTPHeaderField: key)
      }
    }

    return newRequest
  }

  func createFreshRequestWithoutAuthHeaders() -> URLRequest {
    var newRequest = URLRequest(url: self.url!)
    newRequest.httpMethod = self.httpMethod
    newRequest.httpBody = self.httpBody

    // Copy all non-auth headers
    for (key, value) in self.allHTTPHeaderFields ?? [:] {
      if key != "Authorization" && key != "DPoP" {
        newRequest.setValue(value, forHTTPHeaderField: key)
      }
    }

    return newRequest
  }
}
