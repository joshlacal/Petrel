import Foundation
@testable import Petrel
import Testing

/// The TID specification requires that a generator never repeats an identifier and
/// never goes backwards, including when it is called faster than its clock ticks.
@Suite("TID generator: uniqueness and monotonic order")
struct TIDGeneratorStressTests {
    /// A single caller in a tight loop outruns a millisecond clock by three orders of
    /// magnitude, which is the case that used to hand out duplicates.
    @Test("400,000 sequential identifiers are unique and strictly increasing")
    func sequentialBurstIsStrictlyIncreasing() async {
        let count = 400_000
        var previous = ""
        var outOfOrder = 0
        var seen = Set<String>(minimumCapacity: count)

        for _ in 0 ..< count {
            let tid = await TIDGenerator.next()
            if tid <= previous {
                outOfOrder += 1
            }
            previous = tid
            seen.insert(tid)
        }

        #expect(outOfOrder == 0)
        #expect(seen.count == count)
    }

    @Test("64 concurrent callers never receive the same identifier")
    func concurrentCallersReceiveDistinctIdentifiers() async {
        let tasks = 64
        let perTask = 5000

        let batches = await withTaskGroup(of: [String].self) { group in
            for _ in 0 ..< tasks {
                group.addTask {
                    var batch: [String] = []
                    batch.reserveCapacity(perTask)
                    for _ in 0 ..< perTask {
                        batch.append(await TIDGenerator.next())
                    }
                    return batch
                }
            }
            var collected: [[String]] = []
            for await batch in group {
                collected.append(batch)
            }
            return collected
        }

        var seen = Set<String>(minimumCapacity: tasks * perTask)
        for batch in batches {
            // Each caller sees its own identifiers in strictly increasing order.
            #expect(zip(batch, batch.dropFirst()).allSatisfy { $0 < $1 })
            seen.formUnion(batch)
        }
        #expect(seen.count == tasks * perTask)
    }

    // MARK: - Deterministic clock

    /// A clock the test controls, standing in for the system clock.
    private final class ManualClock: @unchecked Sendable {
        private let lock = NSLock()
        private var microseconds: UInt64

        init(_ microseconds: UInt64) {
            self.microseconds = microseconds
        }

        var now: UInt64 {
            lock.lock()
            defer { lock.unlock() }
            return microseconds
        }

        func set(_ value: UInt64) {
            lock.lock()
            microseconds = value
            lock.unlock()
        }
    }

    /// The exact failure the audit reproduced: more identifiers requested than the
    /// clock has ticks. With the clock frozen every call must still move forward.
    @Test("a frozen clock still yields 5,000 strictly increasing identifiers")
    func frozenClock() async {
        let clock = ManualClock(1_700_000_000_000_000)
        let generator = TIDGenerator(clockID: 7, clock: { clock.now })

        var previous: TID?
        for index in 0 ..< 5000 {
            let tid = await generator.nextTID()
            #expect(tid.clockID == 7)
            #expect(tid.timestampMicros == 1_700_000_000_000_000 + UInt64(index))
            if let previous {
                #expect(tid > previous)
                #expect(tid.toString() > previous.toString())
            }
            previous = tid
        }
    }

    @Test("a clock that steps backwards never produces an earlier identifier")
    func clockStepsBackwards() async {
        let clock = ManualClock(1_700_000_000_000_000)
        let generator = TIDGenerator(clockID: 0, clock: { clock.now })

        let first = await generator.nextTID()
        clock.set(1_600_000_000_000_000) // more than three years earlier
        let second = await generator.nextTID()
        let third = await generator.nextTID()
        #expect(second > first)
        #expect(third > second)
        #expect(second.timestampMicros == first.timestampMicros + 1)

        // Once the clock catches up, identifiers follow it again.
        clock.set(1_800_000_000_000_000)
        let fourth = await generator.nextTID()
        #expect(fourth.timestampMicros == 1_800_000_000_000_000)
    }

    @Test("the clock identifier is fixed for the life of a generator")
    func clockIdentifierIsFixed() async {
        let generator = TIDGenerator()
        #expect(generator.clockID < 1024)
        for _ in 0 ..< 2000 {
            #expect(await generator.nextTID().clockID == generator.clockID)
        }
        #expect(TIDGenerator(clockID: 1023).clockID == 1023)
    }

    @Test("two generators with different clock identifiers never collide on the same microsecond")
    func distinctClockIdentifiers() async {
        let clock = ManualClock(1_700_000_000_000_000)
        let one = TIDGenerator(clockID: 1, clock: { clock.now })
        let two = TIDGenerator(clockID: 2, clock: { clock.now })
        let first = await one.nextTID()
        let second = await two.nextTID()
        #expect(first.timestampMicros == second.timestampMicros)
        #expect(first != second)
        #expect(first.toString() != second.toString())
    }

    @Test("next(after:) always exceeds the given revision")
    func nextAfter() async throws {
        let clock = ManualClock(1_700_000_000_000_000)
        let generator = TIDGenerator(clockID: 3, clock: { clock.now })

        // Behind the clock: the clock wins.
        let older = try TID(timestampMicros: 1_600_000_000_000_000, clockID: 9)
        let afterOlder = try await generator.next(after: older)
        #expect(afterOlder > older)
        #expect(afterOlder.timestampMicros == 1_700_000_000_000_000)

        // Ahead of the clock (the other writer's clock was fast): one microsecond later.
        let ahead = try TID(timestampMicros: 1_900_000_000_000_000, clockID: 1023)
        let afterAhead = try await generator.next(after: ahead)
        #expect(afterAhead > ahead)
        #expect(afterAhead.timestampMicros == 1_900_000_000_000_001)
        #expect(afterAhead.clockID == 3)

        // A far-future revision does not drag the generator's own output forward.
        let ordinary = await generator.nextTID()
        #expect(ordinary.timestampMicros < 1_800_000_000_000_000)
        #expect(ordinary > afterOlder)

        // No previous revision: same as nextTID().
        let fresh = try await generator.next(after: nil)
        #expect(fresh > ordinary)

        // Nothing can follow the largest timestamp.
        let last = try TID(timestampMicros: (1 << 53) - 1, clockID: 0)
        await #expect(throws: ATProtocolError.self) { try await generator.next(after: last) }
    }

    @Test("every generated identifier is a valid TID")
    func generatedIdentifiersAreValid() async {
        for _ in 0 ..< 2000 {
            let tid = await TIDGenerator.next()
            #expect(TID.isValidTID(tid))
            #expect(tid.utf8.count == 13)
        }
    }
}
