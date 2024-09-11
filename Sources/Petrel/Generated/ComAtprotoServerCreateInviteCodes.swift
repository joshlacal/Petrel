import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.server.createInviteCodes

public enum ComAtprotoServerCreateInviteCodes {
    public static let typeIdentifier = "com.atproto.server.createInviteCodes"

    public struct AccountCodes: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.server.createInviteCodes#accountCodes"
        public let account: String
        public let codes: [String]

        // Standard initializer
        public init(
            account: String, codes: [String]
        ) {
            self.account = account
            self.codes = codes
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                account = try container.decode(String.self, forKey: .account)

            } catch {
                LogManager.logError("Decoding error for property 'account': \(error)")
                throw error
            }
            do {
                codes = try container.decode([String].self, forKey: .codes)

            } catch {
                LogManager.logError("Decoding error for property 'codes': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(account, forKey: .account)

            try container.encode(codes, forKey: .codes)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(account)
            hasher.combine(codes)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if account != other.account {
                return false
            }

            if codes != other.codes {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case account
            case codes
        }
    }

    public struct Input: ATProtocolCodable {
        public let codeCount: Int
        public let useCount: Int
        public let forAccounts: [String]?

        // Standard public initializer
        public init(codeCount: Int, useCount: Int, forAccounts: [String]? = nil) {
            self.codeCount = codeCount
            self.useCount = useCount
            self.forAccounts = forAccounts
        }
    }

    public struct Output: ATProtocolCodable {
        public let codes: [AccountCodes]

        // Standard public initializer
        public init(
            codes: [AccountCodes]
        ) {
            self.codes = codes
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Create invite codes.
    func createInviteCodes(
        input: ComAtprotoServerCreateInviteCodes.Input,

        duringInitialSetup: Bool = false
    ) async throws -> (responseCode: Int, data: ComAtprotoServerCreateInviteCodes.Output?) {
        let endpoint = "/com.atproto.server.createInviteCodes"

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

        let decodedData = try? ZippyJSONDecoder().decode(ComAtprotoServerCreateInviteCodes.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
