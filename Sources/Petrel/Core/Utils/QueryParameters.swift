//
//  QueryParameters.swift
//  Petrel
//
//  Created by Josh LaCalamito on 11/20/23.
//

import Foundation

public protocol Parametrizable: Sendable {}

public extension Parametrizable {
    func asQueryItems() -> [URLQueryItem] {
        let mirror = Mirror(reflecting: self)
        return mirror.children.flatMap { child -> [URLQueryItem] in
            guard let label = child.label else { return [] }

            if let array = child.value as? [QueryParameterConvertible] {
                return array.map { $0.asQueryItem(name: label) }.compactMap { $0 }
            } else if let value = child.value as? QueryParameterConvertible {
                return [value.asQueryItem(name: label)].compactMap { $0 }
            } else if let seq = child.value as? any Sequence {
                var items: [URLQueryItem] = []
                for element in seq {
                    let elemVal: String
                    if let raw = (element as? any RawRepresentable)?.rawValue {
                        elemVal = String(describing: raw)
                    } else {
                        elemVal = String(describing: element)
                    }
                    items.append(URLQueryItem(name: label, value: elemVal))
                }
                return items
            } else if let raw = (child.value as? any RawRepresentable)?.rawValue {
                return [URLQueryItem(name: label, value: String(describing: raw))]
            }

            return []
        }
    }
}

protocol QueryParameterConvertible {
    func asQueryItem(name: String) -> URLQueryItem?
}

extension String: QueryParameterConvertible {
    func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: self)
    }
}

extension Bool: QueryParameterConvertible {
    func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: self ? "true" : "false")
    }
}

extension Int: QueryParameterConvertible {
    func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: String(self))
    }
}

extension Optional where Wrapped: QueryParameterConvertible {
    func asQueryItem(name: String) -> URLQueryItem? {
        switch self {
        case let .some(value):
            return value.asQueryItem(name: name)
        case .none:
            return nil
        }
    }
}
