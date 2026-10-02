import Foundation

/// Ordered map structure for DAG-CBOR encoding
public struct OrderedCBORMap: DAGCBOREncodable {
    public private(set) var entries: [(key: String, value: Any)]

    public init() {
        entries = []
    }

    public init(minimumCapacity: Int) {
        entries = []
        entries.reserveCapacity(minimumCapacity)
    }

    public init(entries: [(key: String, value: Any)]) {
        self.entries = entries
    }

    public mutating func append(key: String, value: Any) {
        entries.append((key: key, value: value))
    }

    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        entries.reserveCapacity(minimumCapacity)
    }

    /// Returns this map with one more entry appended.
    ///
    /// `consuming` (SE-0377) takes ownership of `self`, so the common builder
    /// pattern `map = map.adding(key:value:)` appends into the existing entries
    /// buffer instead of copying every earlier entry on each call. Callers that
    /// keep using the original map still get an independent copy (Swift copies
    /// implicitly before the consume), so the result is unchanged.
    public consuming func adding(key: String, value: Any) -> OrderedCBORMap {
        append(key: key, value: value)
        return self
    }

    /// Builds the DAG-CBOR map for one variant of a generated union.
    ///
    /// The result is `$type` first, followed by the payload's entries in their
    /// original order with any payload `$type` entry dropped. A payload that is
    /// neither an `OrderedCBORMap` nor a `[String: Any]` contributes no entries.
    /// This is exactly what the generated `map = map.adding(...)` sequence
    /// produced, built once at its final size.
    public static func unionVariant(typeIdentifier: String, payload: Any) -> OrderedCBORMap {
        if let orderedMap = payload as? OrderedCBORMap {
            var map = OrderedCBORMap(minimumCapacity: orderedMap.entries.count + 1)
            map.append(key: "$type", value: typeIdentifier)
            for (key, value) in orderedMap.entries where key != "$type" {
                map.append(key: key, value: value)
            }
            return map
        }
        if let dictionary = payload as? [String: Any] {
            var map = OrderedCBORMap(minimumCapacity: dictionary.count + 1)
            map.append(key: "$type", value: typeIdentifier)
            for (key, value) in dictionary where key != "$type" {
                map.append(key: key, value: value)
            }
            return map
        }
        var map = OrderedCBORMap(minimumCapacity: 1)
        map.append(key: "$type", value: typeIdentifier)
        return map
    }

    /// Implementation of DAGCBOREncodable protocol
    public func toCBORValue() throws -> Any {
        // Return self to ensure the OrderedCBORMap is processed as an ordered map
        // in the DAGCBOR.convertToCBORItem method
        return self
    }

    /// Useful for debugging
    public var description: String {
        let contents = entries.map { "\"\($0.key)\": \($0.value)" }.joined(separator: ", ")
        return "OrderedCBORMap({\(contents)})"
    }
}
