//
//  ATProtocolValueContainerHelpers.swift
//  Petrel
//
//  Created by Josh LaCalamito on 11/20/23.
//

import Foundation

public extension ATProtocolValueContainer {
    var textRepresentation: String {
        switch self {
        case let .knownType(value):
            let mirror = Mirror(reflecting: value)
            return mirror.children.map { "\($0.label ?? ""): \($0.value)" }.joined(separator: ", ")
        case let .string(value):
            return value
        case let .number(value):
            return String(value)
        case let .bigNumber(value):
            return value
        case let .object(value):
            return "Object: \(value.description)"
        case let .array(value):
            return "Array: \(value.description)"
        case let .bool(value):
            return value ? "True" : "False"
        case .null:
            return "Null"
        case let .link(value):
            return "Link: \(value)"
        case let .bytes(value):
            return "Bytes: \(value)"
        case let .unknownType(type, dict):
            if case let .object(objectDict) = dict {
                return
                    "Unknown Type: \(type), Values: \(objectDict.map { key, value in "\(key): \(value.textRepresentation)" }.joined(separator: ", "))"
            } else {
                return "Unknown Type: \(type)"
            }
        case let .decodeError(errorMessage):
            return "Decode Error: \(errorMessage)"
        }
    }

    func toJSON() throws -> Any {
        switch self {
        case let .knownType(value):
            return value
        case let .string(value):
            return value
        case let .number(value):
            return value
        case let .bigNumber(value):
            return value
        case let .bool(value):
            return value
        case .null:
            return NSNull()
        case let .link(value):
            return value
        case let .bytes(value):
            return value
        case let .object(dict):
            return try dict.mapValues { try $0.toJSON() }
        case let .array(array):
            return try array.map { try $0.toJSON() }
        case let .unknownType(typeName, ATProtocolValueContainer):
            var jsonDict = [String: Any]()
            if case let .object(dict) = ATProtocolValueContainer {
                for (key, value) in dict {
                    jsonDict[key] = try value.toJSON()
                }
            }
            return ["type": typeName, "value": jsonDict]
        case let .decodeError(value):
            print("Decode Error: \(value.debugDescription)")
            return value
        }
    }

    func toData() throws -> Data {
        let json = try toJSON()
        return try JSONSerialization.data(withJSONObject: json)
    }

    static func == (lhs: ATProtocolValueContainer, rhs: ATProtocolValueContainer) -> Bool {
        switch (lhs, rhs) {
        case let (.string(a), .string(b)):
            return a == b
        case let (.number(a), .number(b)):
            return a == b
        case let (.bigNumber(a), .bigNumber(b)):
            return a == b
        case let (.bool(a), .bool(b)):
            return a == b
        case (.null, .null):
            return true
        case let (.array(a), .array(b)):
            return a == b
        case let (.object(a), .object(b)):
            return a == b
        case let (.knownType(a), .knownType(b)):
            return a.isEqual(to: b)
        case let (.unknownType(typeA, valA), .unknownType(typeB, valB)):
            return typeA == typeB && valA == valB
        case let (.decodeError(a), .decodeError(b)):
            return a == b
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case let .string(value):
            hasher.combine(value)
        case let .number(value):
            hasher.combine(value)
        case let .bigNumber(value):
            hasher.combine(value)
        case let .bool(value):
            hasher.combine(value)
        case .null:
            hasher.combine(0) // Arbitrary choice for null
        case let .array(value):
            hasher.combine(value)
        case let .object(value):
            hasher.combine(value)
        case let .knownType(value):
            value.hash(into: &hasher)
        case let .unknownType(type, value):
            hasher.combine(type)
            hasher.combine(value)
        case let .decodeError(error):
            hasher.combine(error)
        default:
            break
        }
    }

    func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? ATProtocolValueContainer else {
            return false
        }
        return self == otherValue
    }
}
