import Foundation
import Testing
@testable import PetrelCore

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

        let data = try JSONCoders.encode(model)
        let decoded = try JSONCoders.decode(SampleModel.self, from: data)
        #expect(decoded == model)
    }

    @Test("ISO8601 JSON coders format and parse ISO8601 dates")
    func iso8601CodersDateHandling() throws {
        let referenceDate = Date(timeIntervalSince1970: 1700000000)
        let model = SampleModel(id: "iso-test", count: 7, date: referenceDate)

        let data = try JSONCoders.encodeISO8601(model)
        let jsonString = try #require(String(data: data, encoding: .utf8))
        #expect(jsonString.contains("2023-11-14T22:13:20Z"))

        let decoded = try JSONCoders.decodeISO8601(SampleModel.self, from: data)
        #expect(abs(decoded.date.timeIntervalSince(referenceDate)) < 1.0)
    }

    @Test("Concurrent encode and decode across tasks")
    func concurrentEncodingDecoding() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0 ..< 100 {
                group.addTask {
                    let model = SampleModel(
                        id: "concurrent-\(i)",
                        count: i,
                        date: Date(timeIntervalSince1970: Double(1700000000 + i))
                    )

                    let defaultData = try JSONCoders.encode(model)
                    let decodedDefault = try JSONCoders.decode(SampleModel.self, from: defaultData)
                    #expect(decodedDefault.id == model.id)
                    #expect(decodedDefault.count == model.count)

                    let isoData = try JSONCoders.encodeISO8601(model)
                    let decodedISO = try JSONCoders.decodeISO8601(SampleModel.self, from: isoData)
                    #expect(decodedISO.id == model.id)
                    #expect(decodedISO.count == model.count)
                }
            }
            try await group.waitForAll()
        }
    }
}
