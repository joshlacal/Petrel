import Foundation
import Petrel
@testable import PetrelLoad
import Testing

@Suite("Auth event JSONL integration", .serialized)
struct AuthEventJSONLIntegrationTests {
    @Test("Awaited registration and drain preserve an immediately logged incident")
    func immediateIncidentIsWrittenBeforeDrainReturns() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("petrel-auth-drain-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try Data().write(to: fileURL)

        await PetrelAuthEvents.removeAllObservers()
        let writer = try AuthEventJSONLWriter(fileURL: fileURL)
        await PetrelAuthEvents.addObserver { event in
            try? await writer.write(event)
        }

        LogManager.logAuthIncident(
            "LogoutNoAutoSwitch",
            details: ["did": "did:plc:drain-test"]
        )
        await PetrelAuthEvents.drain()

        let lines = try String(contentsOf: fileURL, encoding: .utf8)
            .split(separator: "\n")
        let record = try #require(lines.last?.data(using: .utf8))
        let object = try #require(
            JSONSerialization.jsonObject(with: record) as? [String: Any]
        )
        #expect((object["event"] as? String)?.contains("logoutNoAutoSwitch") == true)
        #expect((object["event"] as? String)?.contains("did:plc:drain-test") == true)

        await PetrelAuthEvents.removeAllObservers()
    }
}
