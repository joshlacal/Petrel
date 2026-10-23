//
//  QueryParameters.swift
//  Petrel
//
//  Created by Josh LaCalamito on 11/20/23.
//

import Foundation

public protocol Parametrizable: Sendable {}

private func unwrapOptional(_ value: Any) -> Any? {
    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional {
        return mirror.children.first?.value
    }
    return value
}

public extension Parametrizable {
    func asQueryItems() -> [URLQueryItem] {
        let mirror = Mirror(reflecting: self)
        return mirror.children.flatMap { child -> [URLQueryItem] in
            guard let label = child.label else { return [] }
            guard let unwrapped = unwrapOptional(child.value) else { return [] }

            if let array = unwrapped as? [QueryParameterConvertible] {
                return array.map { $0.asQueryItem(name: label) }.compactMap { $0 }
            } else if let value = unwrapped as? QueryParameterConvertible {
                return [value.asQueryItem(name: label)].compactMap { $0 }
            } else if let seq = unwrapped as? any Sequence {
                var items: [URLQueryItem] = []
                for element in seq {
                    if let value = element as? QueryParameterConvertible {
                        value.asQueryItem(name: label).map { items.append($0) }
                    } else if let raw = (element as? any RawRepresentable)?.rawValue {
                        items.append(URLQueryItem(name: label, value: String(describing: raw)))
                    } else {
                        reportUnencodable(element, label: label)
                    }
                }
                return items
            } else if let raw = (unwrapped as? any RawRepresentable)?.rawValue {
                return [URLQueryItem(name: label, value: String(describing: raw))]
            }

            reportUnencodable(unwrapped, label: label)
            return []
        }
    }
}

/// A leaf with no query encoding would otherwise leave the request without a trace
/// (or, as an array element, go out as its debug description). The fix is a
/// `QueryParameterConvertible` conformance for its type.
private func reportUnencodable(_ value: Any, label: String) {
    let message = "Parametrizable.asQueryItems(): '\(label)' is a \(type(of: value)), "
        + "which has no query encoding; the parameter is not sent"
    LogManager.logError(message, category: .network)
    assertionFailure(message)
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

extension CID: QueryParameterConvertible {
    func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: string)
    }
}

extension ATProtocolDate: QueryParameterConvertible {
    func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: iso8601String)
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
