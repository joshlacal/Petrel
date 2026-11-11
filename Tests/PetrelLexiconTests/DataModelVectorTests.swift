import Foundation
import PetrelCore
@testable import PetrelLexicon
import Testing

/// Runs every case of the official `atproto-interop-tests/data-model` files.
@Suite("Data model: official interop vectors")
struct DataModelVectorTests {
    @Test("data-model-valid.json: every case parses as a record")
    func validVectorsParse() throws {
        let cases = try Vectors.cases("data-model/data-model-valid.json")
        #expect(cases.count == 5)
        for vector in cases {
            let note = try #require(vector["note"]?.string)
            let json = try #require(vector["json"])
            #expect(throws: Never.self, "data-model-valid: \(note)") {
                let value = try LexValue.record(json: json.source)
                // A valid value survives both wire forms unchanged.
                #expect(try LexValue(json: value.jsonData()) == value, "JSON round trip: \(note)")
                #expect(try LexValue(dagCBOR: value.dagCBOR()) == value, "DAG-CBOR round trip: \(note)")
            }
        }
    }

    @Test("data-model-valid.json: an integer-like float is the integer")
    func integerLikeFloatIsAnInteger() throws {
        let cases = try Vectors.cases("data-model/data-model-valid.json")
        let vector = try #require(cases.first { $0["note"]?.string == "float, but integer-like" })
        let json = try #require(vector["json"])
        // The vector must really contain a fractional literal, or this proves nothing.
        #expect(String(decoding: json.source, as: UTF8.self).contains("123.0"))
        let value = try LexValue.record(json: json.source)
        #expect(value["rcrd"]?["a"] == .integer(123))
    }

    /// The reason each invalid vector must be rejected for. A new upstream
    /// case fails the test until its reason is recorded here.
    static let invalidReasons: [String: LexValueError.Code] = [
        "top-level not an object": .notAnObject,
        "float": .floatNotAllowed,
        "record with $type null": .invalidType,
        "record with $type wrong type": .invalidType,
        "record with empty $type string": .invalidType,
        "blob with string size": .malformedBlob,
        "blob with missing key": .malformedBlob,
        "bytes with wrong field type": .malformedBytes,
        "bytes with extra fields": .malformedBytes,
        "link with wrong field type": .malformedLink,
        "link with bogus CID": .invalidCID,
        "link with extra fields": .malformedLink,
    ]

    @Test("data-model-invalid.json: every case is rejected, for the stated reason")
    func invalidVectorsAreRejected() throws {
        let cases = try Vectors.cases("data-model/data-model-invalid.json")
        #expect(cases.count == 12)
        for vector in cases {
            let note = try #require(vector["note"]?.string)
            let json = try #require(vector["json"])
            let expected = try #require(Self.invalidReasons[note], "no expected reason recorded for vector: \(note)")
            do {
                let value = try LexValue.record(json: json.source)
                Issue.record("data-model-invalid vector was accepted: \(note) -> \(value)")
            } catch let error as LexValueError {
                #expect(error.code == expected, "data-model-invalid: \(note) rejected as \(error)")
            }
        }
    }

    @Test("data-model-fixtures.json: JSON -> DAG-CBOR bytes -> CID match the fixtures")
    func fixturesEncodeToTheSameBytesAndCID() throws {
        let cases = try Vectors.cases("data-model/data-model-fixtures.json")
        #expect(cases.count == 3)
        for (index, vector) in cases.enumerated() {
            let json = try #require(vector["json"])
            let expectedCBOR = try #require(vector["cbor_base64"]?.string.flatMap(foundationBase64))
            let expectedCID = try #require(vector["cid"]?.string)

            let value = try LexValue.record(json: json.source)
            let encoded = try value.dagCBOR()
            #expect(encoded == expectedCBOR, "fixture \(index): DAG-CBOR bytes differ")
            #expect(try value.cid().string == expectedCID, "fixture \(index): CID differs")

            // And back: the fixture bytes decode to the same value.
            let decoded = try LexValue(dagCBOR: expectedCBOR)
            #expect(decoded == value, "fixture \(index): decoding the fixture bytes gives a different value")
            #expect(try CID.fromDAGCBOR(expectedCBOR).string == expectedCID, "fixture \(index): fixture bytes do not hash to the fixture CID")
        }
    }

    @Test("data-model-fixtures.json: links, bytes and blobs come out typed")
    func fixtureCompoundTypesAreTyped() throws {
        let cases = try Vectors.cases("data-model/data-model-fixtures.json")
        let json = try #require(cases.dropFirst().first?["json"])
        let value = try LexValue.record(json: json.source)
        let link = try #require(value["a"]?.cidValue)
        #expect(link.codec == .dagCBOR)
        #expect(value["b"]?.bytesValue?.count == 32)
        let blob = try #require(value["c"]?.blobRef)
        #expect(blob.mimeType == "image/jpeg")
        #expect(blob.size == 10000)
        #expect(blob.hasRawCodec)
        #expect(value.blobRefs == [blob])
    }
}
