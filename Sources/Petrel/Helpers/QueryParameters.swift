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
