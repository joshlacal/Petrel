import Foundation
import Testing
@testable import Petrel

@Suite("JSONCoders tests")
struct JSONCodersTests {
    private struct SampleModel: Codable, Equatable, Sendable {
        let id: String
        let count: Int
        let date: Date
    }

    @Test("Default JSON coders roundtrip")
    func defaultCodersRoundtrip() throws {
        let model = SampleModel(
            id: "test-123",
            count: 42,
            date: Date(timeIntervalSince1970: 1700000000)
        )

        let data = try JSONCoders.defaultEncoder.encode(model)
        let decoded = try JSONCoders.defaultDecoder.decode(SampleModel.self, from: data)
        #expect(decoded == model)
    }

    @Test("ISO8601 JSON coders format and parse ISO8601 dates")
    func iso8601CodersDateHandling() throws {
        let referenceDate = Date(timeIntervalSince1970: 1700000000)
        let model = SampleModel(id: "iso-test", count: 7, date: referenceDate)

        let data = try JSONCoders.iso8601Encoder.encode(model)
        let jsonString = try #require(String(data: data, encoding: .utf8))
        #expect(jsonString.contains("2023-11-14T22:13:20Z"))

        let decoded = try JSONCoders.iso8601Decoder.decode(SampleModel.self, from: data)
        #expect(abs(decoded.date.timeIntervalSince(referenceDate)) < 1.0)
    }

    @Test("Concurrent encode and decode across tasks")
    func concurrentEncodingDecoding() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0 ..< 50 {
                group.addTask {
                    let model = SampleModel(
                        id: "concurrent-\(i)",
                        count: i,
                        date: Date(timeIntervalSince1970: Double(1700000000 + i))
                    )

                    let defaultData = try JSONCoders.defaultEncoder.encode(model)
                    let decodedDefault = try JSONCoders.defaultDecoder.decode(SampleModel.self, from: defaultData)
                    #expect(decodedDefault.id == model.id)
                    #expect(decodedDefault.count == model.count)

                    let isoData = try JSONCoders.iso8601Encoder.encode(model)
                    let decodedISO = try JSONCoders.iso8601Decoder.decode(SampleModel.self, from: isoData)
                    #expect(decodedISO.id == model.id)
                    #expect(decodedISO.count == model.count)
                }
            }
            try await group.waitForAll()
        }
    }
}
