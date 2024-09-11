import Foundation
internal import ZippyJSON

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
        input: ComAtprotoAdminSendEmail.Input,

        duringInitialSetup: Bool = false
    ) async throws -> (responseCode: Int, data: ComAtprotoAdminSendEmail.Output?) {
        let endpoint = "/com.atproto.admin.sendEmail"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        let decodedData = try? ZippyJSONDecoder().decode(ComAtprotoAdminSendEmail.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
