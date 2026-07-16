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

    @Test("Queued authentication events preserve FIFO delivery")
    func queuedDeliveryRemainsFIFOWhenFirstObserverIsBlocked() async {
        await PetrelAuthEvents.removeAllObservers()
        let gate = AsyncGate()
        let recorder = AuthEventRecorder()
        let first = AuthEvent.logoutNoAutoSwitch(did: "did:plc:fifo-first")
        let second = AuthEvent.logoutNoAutoSwitch(did: "did:plc:fifo-second")
        await PetrelAuthEvents.addObserverAndWait { event in
            await recorder.record(event)
            if event == first {
                await gate.hold()
            }
        }

        LogManager.logAuthIncident(
            "LogoutNoAutoSwitch",
            details: ["did": "did:plc:fifo-first"]
        )
        await gate.waitUntilHeld()
        LogManager.logAuthIncident(
            "LogoutNoAutoSwitch",
            details: ["did": "did:plc:fifo-second"]
        )

        #expect(await recorder.events == [first])
        await gate.release()
        await PetrelAuthEvents.drain()

        #expect(await recorder.events == [first, second])
        await PetrelAuthEvents.removeAllObservers()
    }

    @Test("Caller cancellation does not abandon an ordered drain")
    func drainCompletesAfterCallerCancellation() async {
        await PetrelAuthEvents.removeAllObservers()
        let deliveryGate = AsyncGate()
        let drainStarted = AsyncSignal()
        let cancellationIssued = AsyncSignal()
        let recorder = AuthEventRecorder()
        let completionRecorder = ObserverCallRecorder()
        await PetrelAuthEvents.addObserverAndWait { event in
            await recorder.record(event)
            await deliveryGate.hold()
        }

        LogManager.logAuthIncident(
            "LogoutNoAutoSwitch",
            details: ["did": "did:plc:cancelled-drain"]
        )
        await deliveryGate.waitUntilHeld()
        let drainTask = Task {
            await drainStarted.signal()
            await cancellationIssued.wait()
            #expect(Task.isCancelled)
            await PetrelAuthEvents.drain()
            await completionRecorder.record("drained")
        }
        await drainStarted.wait()
        drainTask.cancel()
        await cancellationIssued.signal()

        #expect(await completionRecorder.calls.isEmpty)
        await deliveryGate.release()
        await drainTask.value

        #expect(await recorder.events == [.logoutNoAutoSwitch(did: "did:plc:cancelled-drain")])
        #expect(await completionRecorder.calls == ["drained"])
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

private actor AsyncGate {
    private var isHeld = false
    private var isReleased = false
    private var heldWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func hold() async {
        isHeld = true
        let waiters = heldWaiters
        heldWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }

        guard !isReleased else {
            return
        }
        await withCheckedContinuation { continuation in
            if isReleased {
                continuation.resume()
            } else {
                releaseWaiters.append(continuation)
            }
        }
    }

    func waitUntilHeld() async {
        guard !isHeld else {
            return
        }
        await withCheckedContinuation { continuation in
            if isHeld {
                continuation.resume()
            } else {
                heldWaiters.append(continuation)
            }
        }
    }

    func release() {
        isReleased = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}

private actor AsyncSignal {
    private var isSignalled = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func signal() {
        isSignalled = true
        let pendingWaiters = waiters
        waiters.removeAll()
        for waiter in pendingWaiters {
            waiter.resume()
        }
    }

    func wait() async {
        guard !isSignalled else {
            return
        }
        await withCheckedContinuation { continuation in
            if isSignalled {
                continuation.resume()
            } else {
                waiters.append(continuation)
            }
        }
    }
}
