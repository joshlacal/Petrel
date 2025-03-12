import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.admin.sendEmail

public enum ComAtprotoAdminSendEmail {
    public static let typeIdentifier = "com.atproto.admin.sendEmail"
    public struct Input: ATProtocolCodable {
        public let recipientDid: String
        public let content: String
        public let subject: String?
        public let senderDid: String
        public let comment: String?

        // Standard public initializer
        public init(recipientDid: String, content: String, subject: String? = nil, senderDid: String, comment: String? = nil) {
            self.recipientDid = recipientDid
            self.content = content
            self.subject = subject
            self.senderDid = senderDid
            self.comment = comment
        }
    }

    public struct Output: ATProtocolCodable {
        public let sent: Bool

        // Standard public initializer
        public init(
            sent: Bool

        ) {
            self.sent = sent
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    /// Send email to a user's account email address.
    func sendEmail(
        input: ComAtprotoAdminSendEmail.Input

    ) async throws -> (responseCode: Int, data: ComAtprotoAdminSendEmail.Output?) {
        let endpoint = "com.atproto.admin.sendEmail"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
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
        let decodedData = try? decoder.decode(ComAtprotoAdminSendEmail.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
