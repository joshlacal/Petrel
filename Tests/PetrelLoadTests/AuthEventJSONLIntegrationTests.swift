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
        await PetrelAuthEvents.addObserverAndWait { event in
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

    @Test("An observer can drain its own delivery without self-awaiting")
    func observerDrainReturnsImmediately() async {
        await PetrelAuthEvents.removeAllObservers()
        let recorder = AuthEventRecorder()
        await PetrelAuthEvents.addObserverAndWait { event in
            await PetrelAuthEvents.drain()
            await recorder.record(event)
        }

        LogManager.logAuthIncident(
            "LogoutNoAutoSwitch",
            details: ["did": "did:plc:self-drain"]
        )
        await PetrelAuthEvents.drain()

        #expect(await recorder.events == [.logoutNoAutoSwitch(did: "did:plc:self-drain")])
        await PetrelAuthEvents.removeAllObservers()
    }

    @Test("An observer can remove all observers during its own delivery")
    func observerRemovalDoesNotSelfAwait() async {
        await PetrelAuthEvents.removeAllObservers()
        let recorder = AuthEventRecorder()
        await PetrelAuthEvents.addObserverAndWait { event in
            await recorder.record(event)
            await PetrelAuthEvents.removeAllObservers()
        }

        LogManager.logAuthIncident(
            "LogoutNoAutoSwitch",
            details: ["did": "did:plc:first"]
        )
        await PetrelAuthEvents.drain()
        LogManager.logAuthIncident(
            "LogoutNoAutoSwitch",
            details: ["did": "did:plc:second"]
        )
        await PetrelAuthEvents.drain()

        #expect(await recorder.events == [.logoutNoAutoSwitch(did: "did:plc:first")])
        await PetrelAuthEvents.removeAllObservers()
    }

    @Test("Observer removal preserves the current broadcast snapshot")
    func observerRemovalAffectsOnlyFutureBroadcasts() async {
        await PetrelAuthEvents.removeAllObservers()
        let recorder = ObserverCallRecorder()
        await PetrelAuthEvents.addObserverAndWait { _ in
            await recorder.record("removing observer")
            await PetrelAuthEvents.removeAllObservers()
        }
        await PetrelAuthEvents.addObserverAndWait { _ in
            await recorder.record("snapshot observer")
        }

        LogManager.logAuthIncident(
            "LogoutNoAutoSwitch",
            details: ["did": "did:plc:first-snapshot"]
        )
        await PetrelAuthEvents.drain()
        LogManager.logAuthIncident(
            "LogoutNoAutoSwitch",
            details: ["did": "did:plc:future"]
        )
        await PetrelAuthEvents.drain()

        #expect(await recorder.calls == ["removing observer", "snapshot observer"])
        await PetrelAuthEvents.removeAllObservers()
    }

    @Test("Awaited observer lifecycle APIs expose only safe registration")
    func awaitedAPIAccessLevel() throws {
        let source = try String(
            contentsOf: packageRoot
                .appendingPathComponent("Sources/Petrel/Account/AuthEventBroadcaster.swift"),
            encoding: .utf8
        )

        #expect(source.contains("public static func addObserverAndWait"))
        #expect(!source.contains("package static func addObserver("))
        #expect(source.contains("package static func removeAllObservers() async"))
        #expect(source.contains("package static func drain() async"))
        #expect(!source.contains("public static func drain() async"))
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private actor AuthEventRecorder {
    private(set) var events: [AuthEvent] = []

    func record(_ event: AuthEvent) {
        events.append(event)
    }
}

private actor ObserverCallRecorder {
    private(set) var calls: [String] = []

    func record(_ call: String) {
        calls.append(call)
    }
}
