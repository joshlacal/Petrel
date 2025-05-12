import Foundation

// lexicon: 1, id: com.atproto.admin.sendEmail

public enum ComAtprotoAdminSendEmail {
    public static let typeIdentifier = "com.atproto.admin.sendEmail"
    public struct Input: ATProtocolCodable {
        public let recipientDid: DID
        public let content: String
        public let subject: String?
        public let senderDid: DID
        public let comment: String?

        // Standard public initializer
        public init(recipientDid: DID, content: String, subject: String? = nil, senderDid: DID, comment: String? = nil) {
            self.recipientDid = recipientDid
            self.content = content
            self.subject = subject
            self.senderDid = senderDid
            self.comment = comment
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            recipientDid = try container.decode(DID.self, forKey: .recipientDid)

            content = try container.decode(String.self, forKey: .content)

            subject = try container.decodeIfPresent(String.self, forKey: .subject)

            senderDid = try container.decode(DID.self, forKey: .senderDid)

            comment = try container.decodeIfPresent(String.self, forKey: .comment)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(recipientDid, forKey: .recipientDid)

            try container.encode(content, forKey: .content)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(subject, forKey: .subject)

            try container.encode(senderDid, forKey: .senderDid)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(comment, forKey: .comment)
        }

        private enum CodingKeys: String, CodingKey {
            case recipientDid
            case content
            case subject
            case senderDid
            case comment
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let recipientDidValue = try recipientDid.toCBORValue()
            map = map.adding(key: "recipientDid", value: recipientDidValue)

            let contentValue = try content.toCBORValue()
            map = map.adding(key: "content", value: contentValue)

            if let value = subject {
                // Encode optional property even if it's an empty array for CBOR
                let subjectValue = try value.toCBORValue()
                map = map.adding(key: "subject", value: subjectValue)
            }

            let senderDidValue = try senderDid.toCBORValue()
            map = map.adding(key: "senderDid", value: senderDidValue)

            if let value = comment {
                // Encode optional property even if it's an empty array for CBOR
                let commentValue = try value.toCBORValue()
                map = map.adding(key: "comment", value: commentValue)
            }

            return map
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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            sent = try container.decode(Bool.self, forKey: .sent)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(sent, forKey: .sent)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let sentValue = try sent.toCBORValue()
            map = map.adding(key: "sent", value: sentValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case sent
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    // MARK: - sendEmail

    /// Send email to a user's account email address.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func sendEmail(
        input: ComAtprotoAdminSendEmail.Input

    ) async throws -> (responseCode: Int, data: ComAtprotoAdminSendEmail.Output?) {
        let endpoint = "com.atproto.admin.sendEmail"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
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
        let decodedData = try? decoder.decode(ComAtprotoAdminSendEmail.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
