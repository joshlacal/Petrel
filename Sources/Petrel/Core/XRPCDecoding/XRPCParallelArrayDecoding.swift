//
//  XRPCParallelArrayDecoding.swift
//  Petrel
//
//  Opt-in chunk-parallel decode for XRPC outputs whose bulk is one top-level array.
//

import Foundation
import Synchronization

/// An XRPC output whose bulk is ONE required top-level array of independent elements
/// (`feed`, `posts`, `notifications`, `actors`, `records`, ...).
///
/// The generator emits this conformance for every eligible `Output`. It is generated-code support,
/// not an API to adopt by hand: ``XRPCResponseDecoding`` uses it only when the opt-in parallel
/// decode is enabled.
///
/// Contract the generator guarantees: ``init(parallelArrayPrototype:parallelArrayElements:)`` returns
/// `prototype` with only its array member replaced by `elements`. The array member is decoded by
/// `container.decode([ParallelArrayElement].self, forKey:)` in `init(from:)` (a required, non-nullable,
/// non-strict member), so decoding each element on its own is the same work the array decode does.
public protocol XRPCParallelArrayDecodable: Decodable, Sendable {
    /// The array's element type, decoded with its own `init(from:)`.
    associatedtype ParallelArrayElement: Decodable & Sendable
    /// The JSON key of the array member.
    static var parallelArrayKey: String { get }
    /// Returns `prototype` with its array member replaced by `elements` (in document order).
    init(parallelArrayPrototype prototype: Self, parallelArrayElements elements: [ParallelArrayElement])
}

/// The parallel decode engine.
///
/// Equivalence with `JSONDecoder().decode(Output.self, from: data)`:
/// - Whole-document syntax: `JSONDecoder` scans the entire input into its value map before it calls
///   any `init(from:)`. Decoding a no-op type from the ORIGINAL bytes therefore runs exactly the
///   sequential path's parse (same parser, same nesting limit, same encoding detection) and fails
///   exactly when it would.
/// - Non-array members: `Output.init(from:)` itself decodes them, from a copy of the document whose
///   array value is replaced by `[]`. The other members' bytes are copied verbatim, and `init(from:)`
///   cannot observe the array while decoding them, so they decode to the same values (and log the same
///   degrade-to-nil warnings).
/// - Elements: each is decoded by the same `Element.init(from:)` from its own bytes, with a fresh
///   default-configured `JSONDecoder` (no Petrel decode logic reads `codingPath` or `userInfo`), and
///   reassembled in document order.
/// - On ANY failure (scan, prototype or element), the whole response is decoded again sequentially
///   and that outcome is returned or thrown. Errors are therefore identical to the sequential path,
///   including `DecodingError` case, coding path, debug description and underlying error. Failures are
///   rare (the generated endpoint already turns a decode error into `(code, nil)`), so the duplicate
///   work is acceptable.
///
/// Code size: the engine is deliberately NOT specialized per output type
/// (`optimize.sil.specialize.generic.never` + `@inline(never)`). Letting the optimizer specialize it
/// for each of the 92 eligible outputs measured about +0.9 MB of Petrel `__TEXT` for an opt-in path;
/// the unspecialized engine only adds witness-table calls around work that is already generic
/// (Foundation's `JSONDecoder.decode`).
enum XRPCParallelArrayDecoder {
    @_semantics("optimize.sil.specialize.generic.never")
    @inline(never)
    static func decode<Output: XRPCParallelArrayDecodable>(
        _: Output.Type,
        from data: Data,
        configuration: XRPCResponseDecoding.Configuration
    ) async throws -> Output {
        guard data.count >= configuration.parallelMinimumBytes else {
            XRPCResponseDecoding.recordBelowThreshold()
            return try JSONDecoder().decode(Output.self, from: data)
        }
        guard let layout = JSONTopLevelArraySplitter.split(data, arrayKey: Output.parallelArrayKey) else {
            XRPCResponseDecoding.recordSplitterDeclined()
            return try JSONDecoder().decode(Output.self, from: data)
        }
        guard layout.elements.count >= configuration.parallelMinimumElements else {
            XRPCResponseDecoding.recordBelowThreshold()
            return try JSONDecoder().decode(Output.self, from: data)
        }

        let plan = WorkPlan(elementCount: layout.elements.count, configuration: configuration)
        do {
            let value = try await decodeParallel(Output.self, from: data, layout: layout, plan: plan)
            XRPCResponseDecoding.recordParallelDecode()
            return value
        } catch {
            // Reproduce the sequential decoder's exact outcome rather than surfacing a parallel error,
            // whose coding path and message would be relative to one element.
            XRPCResponseDecoding.recordFallbackAfterFailure()
            return try JSONDecoder().decode(Output.self, from: data)
        }
    }

    /// How the elements are divided: `chunkCount` contiguous chunks claimed dynamically by
    /// `workerCount` child tasks.
    struct WorkPlan: Sendable, Equatable {
        let chunkCount: Int
        let workerCount: Int

        init(elementCount: Int, configuration: XRPCResponseDecoding.Configuration) {
            let available = max(1, ProcessInfo.processInfo.activeProcessorCount)
            let workerLimit = max(1, configuration.parallelMaximumWorkers ?? available)
            let requestedChunks = configuration.parallelChunkCount ?? workerLimit * 4
            chunkCount = max(1, min(max(elementCount, 1), requestedChunks))
            workerCount = max(1, min(workerLimit, chunkCount))
        }
    }

    @_semantics("optimize.sil.specialize.generic.never")
    @inline(never)
    static func decodeParallel<Output: XRPCParallelArrayDecodable>(
        _: Output.Type,
        from data: Data,
        layout: JSONTopLevelArraySplitter.Layout,
        plan: WorkPlan
    ) async throws -> Output {
        // Whole-document scan plus the non-array members, concurrent with the element workers.
        async let prototype = decodePrototype(Output.self, from: data, array: layout.array)
        let elements = try await decodeElements(
            Output.ParallelArrayElement.self,
            from: data,
            ranges: layout.elements,
            plan: plan
        )
        return try await Output(parallelArrayPrototype: prototype, parallelArrayElements: elements)
    }

    /// Decodes nothing, so `JSONDecoder.decode` does only its whole-document scan.
    private struct WholeDocumentScan: Decodable {
        init(from _: Decoder) throws {}
    }

    /// Runs the whole-document scan on the original bytes, then decodes `Output` from a copy whose
    /// array value (`array`, the `[` ... `]` byte range) is replaced by `[]`.
    @_semantics("optimize.sil.specialize.generic.never")
    @inline(never)
    static func decodePrototype<Output: XRPCParallelArrayDecodable>(
        _: Output.Type,
        from data: Data,
        array: Range<Int>
    ) throws -> Output {
        _ = try JSONDecoder().decode(WholeDocumentScan.self, from: data)
        let base = data.startIndex
        var blanked = Data()
        blanked.reserveCapacity(data.count - array.count + 2)
        blanked.append(data[base ..< (base + array.lowerBound)])
        blanked.append(contentsOf: [UInt8(ascii: "["), UInt8(ascii: "]")])
        blanked.append(data[(base + array.upperBound)...])
        return try JSONDecoder().decode(Output.self, from: blanked)
    }

    private final class ClaimState: Sendable {
        let nextChunk = Atomic<Int>(0)
        let failed = Atomic<Bool>(false)
    }

    private struct MissingChunk: Error {}

    /// Decodes the element ranges with `plan.workerCount` workers that claim chunks from a shared
    /// atomic cursor (dynamic work claiming) and returns the elements in document order.
    @_semantics("optimize.sil.specialize.generic.never")
    @inline(never)
    static func decodeElements<Element: Decodable & Sendable>(
        _: Element.Type,
        from data: Data,
        ranges: [Range<Int>],
        plan: WorkPlan
    ) async throws -> [Element] {
        let count = ranges.count
        if count == 0 { return [] }
        let chunkCount = min(plan.chunkCount, count)
        let workerCount = min(plan.workerCount, chunkCount)
        let base = data.startIndex
        let state = ClaimState()

        return try await withThrowingTaskGroup(of: [(Int, [Element])].self) { group in
            for _ in 0 ..< workerCount {
                group.addTask {
                    let decoder = JSONDecoder()
                    var produced: [(Int, [Element])] = []
                    while !state.failed.load(ordering: .relaxed) {
                        let chunk = state.nextChunk.wrappingAdd(1, ordering: .relaxed).oldValue
                        guard chunk < chunkCount else { break }
                        let lower = chunk * count / chunkCount
                        let upper = (chunk + 1) * count / chunkCount
                        var elements: [Element] = []
                        elements.reserveCapacity(upper - lower)
                        do {
                            for index in lower ..< upper {
                                let range = ranges[index]
                                let slice = data[(base + range.lowerBound) ..< (base + range.upperBound)]
                                try elements.append(decoder.decode(Element.self, from: slice))
                            }
                        } catch {
                            state.failed.store(true, ordering: .relaxed)
                            throw error
                        }
                        produced.append((chunk, elements))
                    }
                    return produced
                }
            }

            var slots = [[Element]?](repeating: nil, count: chunkCount)
            for try await batch in group {
                for (chunk, elements) in batch {
                    slots[chunk] = elements
                }
            }
            var result: [Element] = []
            result.reserveCapacity(count)
            for slot in slots {
                guard let slot else { throw MissingChunk() }
                result.append(contentsOf: slot)
            }
            return result
        }
    }
}
