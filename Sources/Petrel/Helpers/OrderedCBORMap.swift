import Foundation

/// Ordered map structure for DAG-CBOR encoding
public struct OrderedCBORMap: DAGCBOREncodable {
    let entries: [(key: String, value: Any)]

    public init() {
        entries = []
    }

    public init(entries: [(key: String, value: Any)]) {
        self.entries = entries
    }

    public func adding(key: String, value: Any) -> OrderedCBORMap {
        return OrderedCBORMap(entries: entries + [(key: key, value: value)])
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
