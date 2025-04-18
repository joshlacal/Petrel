import Foundation

// lexicon: 1, id: tools.ozone.communication.defs

public enum ToolsOzoneCommunicationDefs {
    public static let typeIdentifier = "tools.ozone.communication.defs"

    public struct TemplateView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.communication.defs#templateView"
        public let id: String
        public let name: String
        public let subject: String?
        public let contentMarkdown: String
        public let disabled: Bool
        public let lang: LanguageCodeContainer?
        public let lastUpdatedBy: DID
        public let createdAt: ATProtocolDate
        public let updatedAt: ATProtocolDate

        // Standard initializer
        public init(
            id: String, name: String, subject: String?, contentMarkdown: String, disabled: Bool, lang: LanguageCodeContainer?, lastUpdatedBy: DID, createdAt: ATProtocolDate, updatedAt: ATProtocolDate
        ) {
            self.id = id
            self.name = name
            self.subject = subject
            self.contentMarkdown = contentMarkdown
            self.disabled = disabled
            self.lang = lang
            self.lastUpdatedBy = lastUpdatedBy
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                id = try container.decode(String.self, forKey: .id)

            } catch {
                LogManager.logError("Decoding error for property 'id': \(error)")
                throw error
            }
            do {
                name = try container.decode(String.self, forKey: .name)

            } catch {
                LogManager.logError("Decoding error for property 'name': \(error)")
                throw error
            }
            do {
                subject = try container.decodeIfPresent(String.self, forKey: .subject)

            } catch {
                LogManager.logError("Decoding error for property 'subject': \(error)")
                throw error
            }
            do {
                contentMarkdown = try container.decode(String.self, forKey: .contentMarkdown)

            } catch {
                LogManager.logError("Decoding error for property 'contentMarkdown': \(error)")
                throw error
            }
            do {
                disabled = try container.decode(Bool.self, forKey: .disabled)

            } catch {
                LogManager.logError("Decoding error for property 'disabled': \(error)")
                throw error
            }
            do {
                lang = try container.decodeIfPresent(LanguageCodeContainer.self, forKey: .lang)

            } catch {
                LogManager.logError("Decoding error for property 'lang': \(error)")
                throw error
            }
            do {
                lastUpdatedBy = try container.decode(DID.self, forKey: .lastUpdatedBy)

            } catch {
                LogManager.logError("Decoding error for property 'lastUpdatedBy': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                updatedAt = try container.decode(ATProtocolDate.self, forKey: .updatedAt)

            } catch {
                LogManager.logError("Decoding error for property 'updatedAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(id, forKey: .id)

            try container.encode(name, forKey: .name)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(subject, forKey: .subject)

            try container.encode(contentMarkdown, forKey: .contentMarkdown)

            try container.encode(disabled, forKey: .disabled)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(lang, forKey: .lang)

            try container.encode(lastUpdatedBy, forKey: .lastUpdatedBy)

            try container.encode(createdAt, forKey: .createdAt)

            try container.encode(updatedAt, forKey: .updatedAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(name)
            if let value = subject {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(contentMarkdown)
            hasher.combine(disabled)
            if let value = lang {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(lastUpdatedBy)
            hasher.combine(createdAt)
            hasher.combine(updatedAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if id != other.id {
                return false
            }

            if name != other.name {
                return false
            }

            if subject != other.subject {
                return false
            }

            if contentMarkdown != other.contentMarkdown {
                return false
            }

            if disabled != other.disabled {
                return false
            }

            if lang != other.lang {
                return false
            }

            if lastUpdatedBy != other.lastUpdatedBy {
                return false
            }

            if createdAt != other.createdAt {
                return false
            }

            if updatedAt != other.updatedAt {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let idValue = try (id as? DAGCBOREncodable)?.toCBORValue() ?? id
            map = map.adding(key: "id", value: idValue)

            let nameValue = try (name as? DAGCBOREncodable)?.toCBORValue() ?? name
            map = map.adding(key: "name", value: nameValue)

            if let value = subject {
                // Encode optional property even if it's an empty array for CBOR

                let subjectValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "subject", value: subjectValue)
            }

            let contentMarkdownValue = try (contentMarkdown as? DAGCBOREncodable)?.toCBORValue() ?? contentMarkdown
            map = map.adding(key: "contentMarkdown", value: contentMarkdownValue)

            let disabledValue = try (disabled as? DAGCBOREncodable)?.toCBORValue() ?? disabled
            map = map.adding(key: "disabled", value: disabledValue)

            if let value = lang {
                // Encode optional property even if it's an empty array for CBOR

                let langValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "lang", value: langValue)
            }

            let lastUpdatedByValue = try (lastUpdatedBy as? DAGCBOREncodable)?.toCBORValue() ?? lastUpdatedBy
            map = map.adding(key: "lastUpdatedBy", value: lastUpdatedByValue)

            let createdAtValue = try (createdAt as? DAGCBOREncodable)?.toCBORValue() ?? createdAt
            map = map.adding(key: "createdAt", value: createdAtValue)

            let updatedAtValue = try (updatedAt as? DAGCBOREncodable)?.toCBORValue() ?? updatedAt
            map = map.adding(key: "updatedAt", value: updatedAtValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case name
            case subject
            case contentMarkdown
            case disabled
            case lang
            case lastUpdatedBy
            case createdAt
            case updatedAt
        }
    }
}
