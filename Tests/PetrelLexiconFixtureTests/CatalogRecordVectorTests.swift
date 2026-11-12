import Foundation
import Petrel
import PetrelLexiconFixture
import Testing

/// The official `atproto-interop-tests/lexicon` record vectors, read through the Swift type
/// the generator produces for the official catalog Lexicon `example.lexicon.record`.
///
/// A generated type enforces the *shape* of data: field types, required and nullable
/// fields, string formats, union membership. Value *constraints* (lengths, ranges, enums of
/// integers, `const`, blob size and MIME type) are schema metadata it does not carry; those
/// are enforced by the runtime validator in `PetrelLexicon`, which runs the same vectors.
/// This suite pins exactly where that line is.
@Suite("Third-party lexicon fixture: official record vectors")
struct CatalogRecordVectorTests {
    private struct Vector {
        let name: String
        /// The record exactly as the vector file spells it.
        let json: Data
    }

    private static func vectors(_ file: String) throws -> [Vector] {
        let url = try #require(
            Bundle.module.url(forResource: file, withExtension: "json", subdirectory: "Vectors/lexicon")
        )
        let entries = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
        return try entries.map { entry in
            try Vector(
                name: #require(entry["name"] as? String),
                json: JSONSerialization.data(withJSONObject: #require(entry["data"]), options: [.fragmentsAllowed])
            )
        }
    }

    /// A JSON tree with every `{"$bytes": "<base64>"}` replaced by the bytes it denotes, so
    /// two spellings of the same bytes compare equal. The vectors write `"$bytes": "123"`,
    /// which is not the canonical base64 of the two bytes it decodes to.
    private static func normalized(_ json: Any) throws -> NSObject {
        if let object = json as? [String: Any] {
            if object.count == 1, let base64 = object["$bytes"] as? String {
                let wrapped = try JSONEncoder().encode(["$bytes": base64])
                return try JSONDecoder().decode(Bytes.self, from: wrapped).data as NSData
            }
            return try object.mapValues(normalized) as NSDictionary
        }
        if let array = json as? [Any] {
            return try array.map(normalized) as NSArray
        }
        return try #require(json as? NSObject)
    }

    /// Invalid vectors whose only fault is a value constraint. Structurally they are valid
    /// instances of the generated type.
    private static let constraintOnlyVectors: Set<String> = [
        "wrong const value",
        "integer not in enum",
        "out of integer range",
        "string too short",
        "string too long",
        "string too short (graphemes)",
        "string too long (graphemes)",
        "bytes too short",
        "bytes too long",
        "array too short",
        "array too long",
        "blob too large",
        "blob wrong type",
    ]

    @Test("Every valid record vector decodes strictly and re-encodes to the same data")
    func validRecordsRoundTrip() throws {
        let vectors = try Self.vectors("record-data-valid")
        #expect(vectors.count == 3)

        for vector in vectors {
            let record = try ATProtoDecoding.strictJSONDecoder().decode(ExampleLexiconRecord.self, from: vector.json)
            let reencoded = try Self.normalized(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)))
            let original = try Self.normalized(JSONSerialization.jsonObject(with: vector.json))
            #expect(reencoded == original, "vector '\(vector.name)' changed in a round trip")

            let untyped = try JSONDecoder().decode([String: ATProtocolValueContainer].self, from: vector.json)
            #expect(
                try record.encodedDAGCBOR() == ATProtocolValueContainer.object(untyped).encodedDAGCBOR(),
                "vector '\(vector.name)' changed its DAG-CBOR encoding"
            )
        }
    }

    @Test("Every structurally invalid record vector is rejected by the generated type")
    func invalidRecordsAreRejected() throws {
        let vectors = try Self.vectors("record-data-invalid")
        #expect(vectors.count == 50)
        #expect(Self.constraintOnlyVectors.isSubset(of: Set(vectors.map(\.name))))

        var accepted: [String] = []
        for vector in vectors {
            do {
                _ = try ATProtoDecoding.strictJSONDecoder().decode(ExampleLexiconRecord.self, from: vector.json)
                accepted.append(vector.name)
            } catch {}
        }

        let unexpectedlyAccepted = Set(accepted).subtracting(Self.constraintOnlyVectors)
        #expect(unexpectedlyAccepted.isEmpty, "structurally invalid but accepted: \(unexpectedlyAccepted.sorted())")
        let unexpectedlyRejected = Self.constraintOnlyVectors.subtracting(accepted)
        #expect(unexpectedlyRejected.isEmpty, "only a constraint is violated but rejected: \(unexpectedlyRejected.sorted())")
    }
}
