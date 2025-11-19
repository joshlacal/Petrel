import Foundation

// MARK: - Lexicon Root

struct Lexicon: Codable {
    let lexicon: Int
    let id: String
    let defs: [String: LexiconDef]
    let description: String?
}

// MARK: - Definition Types

struct LexiconDef: Codable {
    let type: String
    let description: String?
    let key: String?

    // For records
    let record: LexiconObject?

    // For queries and procedures
    let parameters: LexiconParams?
    let input: LexiconBody?
    let output: LexiconBody?
    let errors: [LexiconError]?

    // For objects
    let required: [String]?
    let nullable: [String]?
    let properties: [String: LexiconProperty]?

    // For subscriptions
    let message: LexiconMessageSchema?

    // For arrays
    let items: LexiconType?
    let minLength: Int?
    let maxLength: Int?

    // For strings
    let format: String?
    let knownValues: [String]?
    let `enum`: [String]?
    let const: String?
    let maxGraphemes: Int?
    let minGraphemes: Int?

    // For integers/numbers
    let minimum: Int?
    let maximum: Int?

    // For unions
    let refs: [String]?

    // For refs
    let ref: String?
}

// MARK: - Lexicon Object

struct LexiconObject: Codable {
    let type: String
    let required: [String]?
    let nullable: [String]?
    let properties: [String: LexiconProperty]?
    let description: String?
}

// MARK: - Lexicon Property (can be many types)

enum LexiconProperty: Codable {
    case type(LexiconType)
    case object(LexiconObject)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let obj = try? container.decode(LexiconObject.self) {
            self = .object(obj)
        } else if let type = try? container.decode(LexiconType.self) {
            self = .type(type)
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid property"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .type(let type):
            try container.encode(type)
        case .object(let obj):
            try container.encode(obj)
        }
    }
}

// MARK: - Lexicon Type

struct LexiconType: Codable {
    let type: String
    let description: String?
    let format: String?
    let ref: String?
    let refs: [String]?
    let items: Box<LexiconType>?
    let properties: [String: LexiconProperty]?
    let required: [String]?
    let nullable: [String]?
    let knownValues: [String]?
    let `enum`: [String]?
    let const: String?
    let maxLength: Int?
    let minLength: Int?
    let maxGraphemes: Int?
    let minGraphemes: Int?
    let minimum: Int?
    let maximum: Int?
    let `default`: AnyCodable?

    // For subscription message schemas
    let schema: Box<LexiconType>?
}

// MARK: - Helper Types

struct LexiconParams: Codable {
    let type: String
    let required: [String]?
    let properties: [String: LexiconProperty]?
}

struct LexiconBody: Codable {
    let encoding: String
    let schema: LexiconType?
    let description: String?
}

struct LexiconError: Codable {
    let name: String
    let description: String?
}

struct LexiconMessageSchema: Codable {
    let schema: LexiconType?
}

// MARK: - Box for recursive types

struct Box<T: Codable>: Codable {
    let value: T

    init(_ value: T) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(T.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - AnyCodable for dynamic values

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
