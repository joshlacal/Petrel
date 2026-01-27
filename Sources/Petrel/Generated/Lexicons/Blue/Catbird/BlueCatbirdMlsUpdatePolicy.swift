import Foundation

// lexicon: 1, id: blue.catbird.mls.updatePolicy

public enum BlueCatbirdMlsUpdatePolicy {
    public static let typeIdentifier = "blue.catbird.mls.updatePolicy"

    public struct PolicyView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.updatePolicy#policyView"
        public let convoId: String
        public let allowInvites: Bool
        public let adminOnlyInvites: Bool
        public let allowMemberAdd: Bool
        public let allowMemberRemove: Bool
        public let requireAdminApproval: Bool
        public let maxMembers: Int
        public let updatedAt: ATProtocolDate
        public let updatedBy: DID?

        /// Standard initializer
        public init(
            convoId: String, allowInvites: Bool, adminOnlyInvites: Bool, allowMemberAdd: Bool, allowMemberRemove: Bool, requireAdminApproval: Bool, maxMembers: Int, updatedAt: ATProtocolDate, updatedBy: DID?
        ) {
            self.convoId = convoId
            self.allowInvites = allowInvites
            self.adminOnlyInvites = adminOnlyInvites
            self.allowMemberAdd = allowMemberAdd
            self.allowMemberRemove = allowMemberRemove
            self.requireAdminApproval = requireAdminApproval
            self.maxMembers = maxMembers
            self.updatedAt = updatedAt
            self.updatedBy = updatedBy
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                convoId = try container.decode(String.self, forKey: .convoId)

            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")

                throw error
            }
            do {
                allowInvites = try container.decode(Bool.self, forKey: .allowInvites)

            } catch {
                LogManager.logError("Decoding error for required property 'allowInvites': \(error)")

                throw error
            }
            do {
                adminOnlyInvites = try container.decode(Bool.self, forKey: .adminOnlyInvites)

            } catch {
                LogManager.logError("Decoding error for required property 'adminOnlyInvites': \(error)")

                throw error
            }
            do {
                allowMemberAdd = try container.decode(Bool.self, forKey: .allowMemberAdd)

            } catch {
                LogManager.logError("Decoding error for required property 'allowMemberAdd': \(error)")

                throw error
            }
            do {
                allowMemberRemove = try container.decode(Bool.self, forKey: .allowMemberRemove)

            } catch {
                LogManager.logError("Decoding error for required property 'allowMemberRemove': \(error)")

                throw error
            }
            do {
                requireAdminApproval = try container.decode(Bool.self, forKey: .requireAdminApproval)

            } catch {
                LogManager.logError("Decoding error for required property 'requireAdminApproval': \(error)")

                throw error
            }
            do {
                maxMembers = try container.decode(Int.self, forKey: .maxMembers)

            } catch {
                LogManager.logError("Decoding error for required property 'maxMembers': \(error)")

                throw error
            }
            do {
                updatedAt = try container.decode(ATProtocolDate.self, forKey: .updatedAt)

            } catch {
                LogManager.logError("Decoding error for required property 'updatedAt': \(error)")

                throw error
            }
            do {
                updatedBy = try container.decodeIfPresent(DID.self, forKey: .updatedBy)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'updatedBy': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(convoId, forKey: .convoId)

            try container.encode(allowInvites, forKey: .allowInvites)

            try container.encode(adminOnlyInvites, forKey: .adminOnlyInvites)

            try container.encode(allowMemberAdd, forKey: .allowMemberAdd)

            try container.encode(allowMemberRemove, forKey: .allowMemberRemove)

            try container.encode(requireAdminApproval, forKey: .requireAdminApproval)

            try container.encode(maxMembers, forKey: .maxMembers)

            try container.encode(updatedAt, forKey: .updatedAt)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(updatedBy, forKey: .updatedBy)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(convoId)
            hasher.combine(allowInvites)
            hasher.combine(adminOnlyInvites)
            hasher.combine(allowMemberAdd)
            hasher.combine(allowMemberRemove)
            hasher.combine(requireAdminApproval)
            hasher.combine(maxMembers)
            hasher.combine(updatedAt)
            if let value = updatedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if convoId != other.convoId {
                return false
            }

            if allowInvites != other.allowInvites {
                return false
            }

            if adminOnlyInvites != other.adminOnlyInvites {
                return false
            }

            if allowMemberAdd != other.allowMemberAdd {
                return false
            }

            if allowMemberRemove != other.allowMemberRemove {
                return false
            }

            if requireAdminApproval != other.requireAdminApproval {
                return false
            }

            if maxMembers != other.maxMembers {
                return false
            }

            if updatedAt != other.updatedAt {
                return false
            }

            if updatedBy != other.updatedBy {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)

            let allowInvitesValue = try allowInvites.toCBORValue()
            map = map.adding(key: "allowInvites", value: allowInvitesValue)

            let adminOnlyInvitesValue = try adminOnlyInvites.toCBORValue()
            map = map.adding(key: "adminOnlyInvites", value: adminOnlyInvitesValue)

            let allowMemberAddValue = try allowMemberAdd.toCBORValue()
            map = map.adding(key: "allowMemberAdd", value: allowMemberAddValue)

            let allowMemberRemoveValue = try allowMemberRemove.toCBORValue()
            map = map.adding(key: "allowMemberRemove", value: allowMemberRemoveValue)

            let requireAdminApprovalValue = try requireAdminApproval.toCBORValue()
            map = map.adding(key: "requireAdminApproval", value: requireAdminApprovalValue)

            let maxMembersValue = try maxMembers.toCBORValue()
            map = map.adding(key: "maxMembers", value: maxMembersValue)

            let updatedAtValue = try updatedAt.toCBORValue()
            map = map.adding(key: "updatedAt", value: updatedAtValue)

            if let value = updatedBy {
                // Encode optional property even if it's an empty array for CBOR

                let updatedByValue = try value.toCBORValue()
                map = map.adding(key: "updatedBy", value: updatedByValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case convoId
            case allowInvites
            case adminOnlyInvites
            case allowMemberAdd
            case allowMemberRemove
            case requireAdminApproval
            case maxMembers
            case updatedAt
            case updatedBy
        }
    }

    public struct Input: ATProtocolCodable {
        public let convoId: String
        public let allowInvites: Bool?
        public let adminOnlyInvites: Bool?
        public let allowMemberAdd: Bool?
        public let allowMemberRemove: Bool?
        public let requireAdminApproval: Bool?
        public let maxMembers: Int?

        /// Standard public initializer
        public init(convoId: String, allowInvites: Bool? = nil, adminOnlyInvites: Bool? = nil, allowMemberAdd: Bool? = nil, allowMemberRemove: Bool? = nil, requireAdminApproval: Bool? = nil, maxMembers: Int? = nil) {
            self.convoId = convoId
            self.allowInvites = allowInvites
            self.adminOnlyInvites = adminOnlyInvites
            self.allowMemberAdd = allowMemberAdd
            self.allowMemberRemove = allowMemberRemove
            self.requireAdminApproval = requireAdminApproval
            self.maxMembers = maxMembers
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            convoId = try container.decode(String.self, forKey: .convoId)

            allowInvites = try container.decodeIfPresent(Bool.self, forKey: .allowInvites)

            adminOnlyInvites = try container.decodeIfPresent(Bool.self, forKey: .adminOnlyInvites)

            allowMemberAdd = try container.decodeIfPresent(Bool.self, forKey: .allowMemberAdd)

            allowMemberRemove = try container.decodeIfPresent(Bool.self, forKey: .allowMemberRemove)

            requireAdminApproval = try container.decodeIfPresent(Bool.self, forKey: .requireAdminApproval)

            maxMembers = try container.decodeIfPresent(Int.self, forKey: .maxMembers)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(convoId, forKey: .convoId)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(allowInvites, forKey: .allowInvites)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(adminOnlyInvites, forKey: .adminOnlyInvites)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(allowMemberAdd, forKey: .allowMemberAdd)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(allowMemberRemove, forKey: .allowMemberRemove)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(requireAdminApproval, forKey: .requireAdminApproval)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(maxMembers, forKey: .maxMembers)
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case allowInvites
            case adminOnlyInvites
            case allowMemberAdd
            case allowMemberRemove
            case requireAdminApproval
            case maxMembers
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)

            if let value = allowInvites {
                // Encode optional property even if it's an empty array for CBOR
                let allowInvitesValue = try value.toCBORValue()
                map = map.adding(key: "allowInvites", value: allowInvitesValue)
            }

            if let value = adminOnlyInvites {
                // Encode optional property even if it's an empty array for CBOR
                let adminOnlyInvitesValue = try value.toCBORValue()
                map = map.adding(key: "adminOnlyInvites", value: adminOnlyInvitesValue)
            }

            if let value = allowMemberAdd {
                // Encode optional property even if it's an empty array for CBOR
                let allowMemberAddValue = try value.toCBORValue()
                map = map.adding(key: "allowMemberAdd", value: allowMemberAddValue)
            }

            if let value = allowMemberRemove {
                // Encode optional property even if it's an empty array for CBOR
                let allowMemberRemoveValue = try value.toCBORValue()
                map = map.adding(key: "allowMemberRemove", value: allowMemberRemoveValue)
            }

            if let value = requireAdminApproval {
                // Encode optional property even if it's an empty array for CBOR
                let requireAdminApprovalValue = try value.toCBORValue()
                map = map.adding(key: "requireAdminApproval", value: requireAdminApprovalValue)
            }

            if let value = maxMembers {
                // Encode optional property even if it's an empty array for CBOR
                let maxMembersValue = try value.toCBORValue()
                map = map.adding(key: "maxMembers", value: maxMembersValue)
            }

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let policy: PolicyView

        /// Standard public initializer
        public init(
            policy: PolicyView

        ) {
            self.policy = policy
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            policy = try container.decode(PolicyView.self, forKey: .policy)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(policy, forKey: .policy)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let policyValue = try policy.toCBORValue()
            map = map.adding(key: "policy", value: policyValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case policy
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case unauthorized = "Unauthorized.Caller is not an admin of this conversation"
        case convoNotFound = "ConvoNotFound.Conversation not found"
        case notMember = "NotMember.Caller is not a member of this conversation"
        case noFieldsProvided = "NoFieldsProvided.At least one policy field must be provided"
        case invalidMaxMembers = "InvalidMaxMembers.maxMembers is less than current member count"
        public var description: String {
            return rawValue
        }

        public var errorName: String {
            // Extract just the error name from the raw value
            let parts = rawValue.split(separator: ".")
            return String(parts.first ?? "")
        }
    }
}

public extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - updatePolicy

    /// Update conversation policy settings Update policy settings for a conversation. Only admins can update policies. At least one policy field must be provided.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func updatePolicy(
        input: BlueCatbirdMlsUpdatePolicy.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsUpdatePolicy.Output?) {
        let endpoint = "blue.catbird.mls.updatePolicy"

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

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.updatePolicy")
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
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(BlueCatbirdMlsUpdatePolicy.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.updatePolicy: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
