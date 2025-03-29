import Foundation

// lexicon: 1, id: com.atproto.admin.disableInviteCodes

public enum ComAtprotoAdminDisableInviteCodes {
    public static let typeIdentifier = "com.atproto.admin.disableInviteCodes"
    public struct Input: ATProtocolCodable {
        public let codes: [String]?
        public let accounts: [String]?

        // Standard public initializer
        public init(codes: [String]? = nil, accounts: [String]? = nil) {
            self.codes = codes
            self.accounts = accounts
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            codes = try container.decodeIfPresent([String].self, forKey: .codes)

            accounts = try container.decodeIfPresent([String].self, forKey: .accounts)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            if let value = codes {
                if !value.isEmpty {
                    try container.encode(value, forKey: .codes)
                }
            }

            if let value = accounts {
                if !value.isEmpty {
                    try container.encode(value, forKey: .accounts)
                }
            }
        }

        private enum CodingKeys: String, CodingKey {
            case codes
            case accounts
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            if let value = codes {
                if !value.isEmpty {
                    let codesValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "codes", value: codesValue)
                }
            }

            if let value = accounts {
                if !value.isEmpty {
                    let accountsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "accounts", value: accountsValue)
                }
            }

            return map
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    /// Disable some set of codes and/or all codes associated with a set of users.
    func disableInviteCodes(
        input: ComAtprotoAdminDisableInviteCodes.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.admin.disableInviteCodes"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
    }
}
