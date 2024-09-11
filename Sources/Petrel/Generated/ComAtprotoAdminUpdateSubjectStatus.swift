import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.admin.updateSubjectStatus

public struct ComAtprotoAdminUpdateSubjectStatus {
    public static let typeIdentifier = "com.atproto.admin.updateSubjectStatus"
    public struct Input: ATProtocolCodable {
        public let subject: InputSubjectUnion
        public let takedown: ComAtprotoAdminDefs.StatusAttr?
        public let deactivated: ComAtprotoAdminDefs.StatusAttr?

        // Standard public initializer
        public init(subject: InputSubjectUnion, takedown: ComAtprotoAdminDefs.StatusAttr? = nil, deactivated: ComAtprotoAdminDefs.StatusAttr? = nil) {
            self.subject = subject
            self.takedown = takedown
            self.deactivated = deactivated
        }
    }

    public struct Output: ATProtocolCodable {
        public let subject: OutputSubjectUnion

        public let takedown: ComAtprotoAdminDefs.StatusAttr?

        // Standard public initializer
        public init(
            subject: OutputSubjectUnion,

            takedown: ComAtprotoAdminDefs.StatusAttr? = nil
        ) {
            self.subject = subject

            self.takedown = takedown
        }
    }

    public enum InputSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue {
        case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
        case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
        case comAtprotoAdminDefsRepoBlobRef(ComAtprotoAdminDefs.RepoBlobRef)
        case unexpected(ATProtocolValueContainer)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)
            LogManager.logDebug("InputSubjectUnion decoding: \(typeValue)")

            switch typeValue {
            case "com.atproto.admin.defs#repoRef":
                LogManager.logDebug("Decoding as com.atproto.admin.defs#repoRef")
                let value = try ComAtprotoAdminDefs.RepoRef(from: decoder)
                self = .comAtprotoAdminDefsRepoRef(value)
            case "com.atproto.repo.strongRef":
                LogManager.logDebug("Decoding as com.atproto.repo.strongRef")
                let value = try ComAtprotoRepoStrongRef(from: decoder)
                self = .comAtprotoRepoStrongRef(value)
            case "com.atproto.admin.defs#repoBlobRef":
                LogManager.logDebug("Decoding as com.atproto.admin.defs#repoBlobRef")
                let value = try ComAtprotoAdminDefs.RepoBlobRef(from: decoder)
                self = .comAtprotoAdminDefsRepoBlobRef(value)
            default:
                LogManager.logDebug("InputSubjectUnion decoding encountered an unexpected type: \(typeValue)")
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                LogManager.logDebug("Encoding com.atproto.admin.defs#repoRef")
                try container.encode("com.atproto.admin.defs#repoRef", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoRepoStrongRef(value):
                LogManager.logDebug("Encoding com.atproto.repo.strongRef")
                try container.encode("com.atproto.repo.strongRef", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoAdminDefsRepoBlobRef(value):
                LogManager.logDebug("Encoding com.atproto.admin.defs#repoBlobRef")
                try container.encode("com.atproto.admin.defs#repoBlobRef", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                LogManager.logDebug("InputSubjectUnion encoding unexpected value")
                try ATProtocolValueContainer.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                hasher.combine("com.atproto.admin.defs#repoRef")
                hasher.combine(value)
            case let .comAtprotoRepoStrongRef(value):
                hasher.combine("com.atproto.repo.strongRef")
                hasher.combine(value)
            case let .comAtprotoAdminDefsRepoBlobRef(value):
                hasher.combine("com.atproto.admin.defs#repoBlobRef")
                hasher.combine(value)
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? InputSubjectUnion else { return false }

            switch (self, otherValue) {
            case let (.comAtprotoAdminDefsRepoRef(selfValue),
                      .comAtprotoAdminDefsRepoRef(otherValue)):
                return selfValue == otherValue
            case let (.comAtprotoRepoStrongRef(selfValue),
                      .comAtprotoRepoStrongRef(otherValue)):
                return selfValue == otherValue
            case let (.comAtprotoAdminDefsRepoBlobRef(selfValue),
                      .comAtprotoAdminDefsRepoBlobRef(otherValue)):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
            }
        }
    }

    public enum OutputSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue {
        case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
        case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
        case comAtprotoAdminDefsRepoBlobRef(ComAtprotoAdminDefs.RepoBlobRef)
        case unexpected(ATProtocolValueContainer)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)
            LogManager.logDebug("OutputSubjectUnion decoding: \(typeValue)")

            switch typeValue {
            case "com.atproto.admin.defs#repoRef":
                LogManager.logDebug("Decoding as com.atproto.admin.defs#repoRef")
                let value = try ComAtprotoAdminDefs.RepoRef(from: decoder)
                self = .comAtprotoAdminDefsRepoRef(value)
            case "com.atproto.repo.strongRef":
                LogManager.logDebug("Decoding as com.atproto.repo.strongRef")
                let value = try ComAtprotoRepoStrongRef(from: decoder)
                self = .comAtprotoRepoStrongRef(value)
            case "com.atproto.admin.defs#repoBlobRef":
                LogManager.logDebug("Decoding as com.atproto.admin.defs#repoBlobRef")
                let value = try ComAtprotoAdminDefs.RepoBlobRef(from: decoder)
                self = .comAtprotoAdminDefsRepoBlobRef(value)
            default:
                LogManager.logDebug("OutputSubjectUnion decoding encountered an unexpected type: \(typeValue)")
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                LogManager.logDebug("Encoding com.atproto.admin.defs#repoRef")
                try container.encode("com.atproto.admin.defs#repoRef", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoRepoStrongRef(value):
                LogManager.logDebug("Encoding com.atproto.repo.strongRef")
                try container.encode("com.atproto.repo.strongRef", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoAdminDefsRepoBlobRef(value):
                LogManager.logDebug("Encoding com.atproto.admin.defs#repoBlobRef")
                try container.encode("com.atproto.admin.defs#repoBlobRef", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                LogManager.logDebug("OutputSubjectUnion encoding unexpected value")
                try ATProtocolValueContainer.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                hasher.combine("com.atproto.admin.defs#repoRef")
                hasher.combine(value)
            case let .comAtprotoRepoStrongRef(value):
                hasher.combine("com.atproto.repo.strongRef")
                hasher.combine(value)
            case let .comAtprotoAdminDefsRepoBlobRef(value):
                hasher.combine("com.atproto.admin.defs#repoBlobRef")
                hasher.combine(value)
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? OutputSubjectUnion else { return false }

            switch (self, otherValue) {
            case let (.comAtprotoAdminDefsRepoRef(selfValue),
                      .comAtprotoAdminDefsRepoRef(otherValue)):
                return selfValue == otherValue
            case let (.comAtprotoRepoStrongRef(selfValue),
                      .comAtprotoRepoStrongRef(otherValue)):
                return selfValue == otherValue
            case let (.comAtprotoAdminDefsRepoBlobRef(selfValue),
                      .comAtprotoAdminDefsRepoBlobRef(otherValue)):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
            }
        }
    }

    public enum ComAtprotoAdminUpdateSubjectStatusSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue {
        case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
        case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
        case comAtprotoAdminDefsRepoBlobRef(ComAtprotoAdminDefs.RepoBlobRef)
        case unexpected(ATProtocolValueContainer)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)
            LogManager.logDebug("ComAtprotoAdminUpdateSubjectStatusSubjectUnion decoding: \(typeValue)")

            switch typeValue {
            case "com.atproto.admin.defs#repoRef":
                LogManager.logDebug("Decoding as com.atproto.admin.defs#repoRef")
                let value = try ComAtprotoAdminDefs.RepoRef(from: decoder)
                self = .comAtprotoAdminDefsRepoRef(value)
            case "com.atproto.repo.strongRef":
                LogManager.logDebug("Decoding as com.atproto.repo.strongRef")
                let value = try ComAtprotoRepoStrongRef(from: decoder)
                self = .comAtprotoRepoStrongRef(value)
            case "com.atproto.admin.defs#repoBlobRef":
                LogManager.logDebug("Decoding as com.atproto.admin.defs#repoBlobRef")
                let value = try ComAtprotoAdminDefs.RepoBlobRef(from: decoder)
                self = .comAtprotoAdminDefsRepoBlobRef(value)
            default:
                LogManager.logDebug("ComAtprotoAdminUpdateSubjectStatusSubjectUnion decoding encountered an unexpected type: \(typeValue)")
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                LogManager.logDebug("Encoding com.atproto.admin.defs#repoRef")
                try container.encode("com.atproto.admin.defs#repoRef", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoRepoStrongRef(value):
                LogManager.logDebug("Encoding com.atproto.repo.strongRef")
                try container.encode("com.atproto.repo.strongRef", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoAdminDefsRepoBlobRef(value):
                LogManager.logDebug("Encoding com.atproto.admin.defs#repoBlobRef")
                try container.encode("com.atproto.admin.defs#repoBlobRef", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                LogManager.logDebug("ComAtprotoAdminUpdateSubjectStatusSubjectUnion encoding unexpected value")
                try ATProtocolValueContainer.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                hasher.combine("com.atproto.admin.defs#repoRef")
                hasher.combine(value)
            case let .comAtprotoRepoStrongRef(value):
                hasher.combine("com.atproto.repo.strongRef")
                hasher.combine(value)
            case let .comAtprotoAdminDefsRepoBlobRef(value):
                hasher.combine("com.atproto.admin.defs#repoBlobRef")
                hasher.combine(value)
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? ComAtprotoAdminUpdateSubjectStatusSubjectUnion else { return false }

            switch (self, otherValue) {
            case let (.comAtprotoAdminDefsRepoRef(selfValue),
                      .comAtprotoAdminDefsRepoRef(otherValue)):
                return selfValue == otherValue
            case let (.comAtprotoRepoStrongRef(selfValue),
                      .comAtprotoRepoStrongRef(otherValue)):
                return selfValue == otherValue
            case let (.comAtprotoAdminDefsRepoBlobRef(selfValue),
                      .comAtprotoAdminDefsRepoBlobRef(otherValue)):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
            }
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    /// Update the service-specific admin status of a subject (account, record, or blob).
    func updateSubjectStatus(
        input: ComAtprotoAdminUpdateSubjectStatus.Input,

        duringInitialSetup: Bool = false
    ) async throws -> (responseCode: Int, data: ComAtprotoAdminUpdateSubjectStatus.Output?) {
        let endpoint = "/com.atproto.admin.updateSubjectStatus"

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

        let decodedData = try? ZippyJSONDecoder().decode(ComAtprotoAdminUpdateSubjectStatus.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
