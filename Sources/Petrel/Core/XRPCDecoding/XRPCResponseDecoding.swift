//
//  XRPCResponseDecoding.swift
//  Petrel
//
//  The single decode entry point used by generated XRPC endpoints.
//

import Foundation
#if canImport(os)
    import os
#endif
import Synchronization

/// Decodes the JSON body of a successful XRPC response into the endpoint's output type.
///
/// Every generated query and procedure with an `application/json` output calls this (through
/// `decodeSuccessfulResponse(_:from:endpoint:)`) instead of constructing a `JSONDecoder` inline.
/// Centralising the call gives three guarantees that do not depend on the caller's (or the
/// module's) default isolation:
///
/// - The decode runs on the global concurrent executor (`@concurrent`), never on the caller's actor,
///   even if Petrel or a consumer later adopts `NonisolatedNonsendingByDefault`.
/// - A task that was cancelled while its request was in flight throws `CancellationError` before
///   paying for the decode (see ``Configuration/checksCancellationBeforeDecode``).
/// - Each decode is bracketed by an `XRPCDecode` signpost interval (Points of Interest) on Apple
///   platforms, so per-endpoint decode cost can be measured on device.
///
/// Outputs whose bulk is one top-level array of independent elements also conform to
/// ``XRPCParallelArrayDecodable``. For those, an opt-in, chunk-parallel decode is available behind
/// the `XRPCDecodeExperimental` SPI. It is disabled by default.
public enum XRPCResponseDecoding {
    // MARK: - Configuration (SPI)

    /// Tuning switches for ``XRPCResponseDecoding``. Exposed only through the
    /// `@_spi(XRPCDecodeExperimental)` import so it can be measured before it becomes API.
    @_spi(XRPCDecodeExperimental)
    public struct Configuration: Sendable, Hashable {
        /// Throw `CancellationError` instead of decoding when the calling task is already cancelled.
        /// Default `true`.
        public var checksCancellationBeforeDecode: Bool
        /// Use the chunk-parallel decode for ``XRPCParallelArrayDecodable`` outputs. Default `false`.
        public var parallelArrayDecoding: Bool
        /// Responses smaller than this always use the sequential decode. Default 64 KiB.
        public var parallelMinimumBytes: Int
        /// Arrays with fewer elements than this always use the sequential decode. Default 8.
        public var parallelMinimumElements: Int
        /// Number of contiguous element chunks that workers claim dynamically.
        /// `nil` picks four chunks per worker (capped at the element count), so that faster cores
        /// (for example P-cores next to E-cores) claim more of the work.
        public var parallelChunkCount: Int?
        /// Maximum number of concurrent element workers. `nil` uses the active processor count.
        public var parallelMaximumWorkers: Int?

        public init(
            checksCancellationBeforeDecode: Bool = true,
            parallelArrayDecoding: Bool = false,
            parallelMinimumBytes: Int = 64 * 1024,
            parallelMinimumElements: Int = 8,
            parallelChunkCount: Int? = nil,
            parallelMaximumWorkers: Int? = nil
        ) {
            self.checksCancellationBeforeDecode = checksCancellationBeforeDecode
            self.parallelArrayDecoding = parallelArrayDecoding
            self.parallelMinimumBytes = parallelMinimumBytes
            self.parallelMinimumElements = parallelMinimumElements
            self.parallelChunkCount = parallelChunkCount
            self.parallelMaximumWorkers = parallelMaximumWorkers
        }

        /// The shipped defaults: cancellation check on, parallel array decoding off.
        public static let standard = Configuration()
    }

    private static let processConfiguration = Mutex(Configuration.standard)

    /// Process-wide configuration. A task-local ``configurationOverride`` takes precedence.
    @_spi(XRPCDecodeExperimental)
    public static var configuration: Configuration {
        get { processConfiguration.withLock { $0 } }
        set { processConfiguration.withLock { $0 = newValue } }
    }

    /// Scoped configuration for the current task and its child tasks (tests, benchmarks).
    @_spi(XRPCDecodeExperimental)
    @TaskLocal public static var configurationOverride: Configuration?

    @inline(__always)
    static func effectiveConfiguration() -> Configuration {
        if let configurationOverride { return configurationOverride }
        return processConfiguration.withLock { $0 }
    }

    // MARK: - Statistics (SPI)

    /// Deterministic counters for the parallel path. They only move while
    /// ``Configuration/parallelArrayDecoding`` is enabled.
    @_spi(XRPCDecodeExperimental)
    public struct Statistics: Sendable, Hashable {
        /// Decodes that completed on the parallel path.
        public var parallelDecodes: Int
        /// Parallel-eligible decodes that used the sequential path because the response was below
        /// the byte or element threshold.
        public var belowThreshold: Int
        /// Decodes where the splitter declined the document (unusual shape), so the sequential path ran.
        public var splitterDeclined: Int
        /// Parallel attempts that failed and were re-run sequentially to reproduce the exact outcome.
        public var fallbacksAfterFailure: Int
    }

    private final class Counters: Sendable {
        let parallelDecodes = Atomic<Int>(0)
        let belowThreshold = Atomic<Int>(0)
        let splitterDeclined = Atomic<Int>(0)
        let fallbacksAfterFailure = Atomic<Int>(0)
    }

    private static let counters = Counters()

    @_spi(XRPCDecodeExperimental)
    public static func statistics() -> Statistics {
        Statistics(
            parallelDecodes: counters.parallelDecodes.load(ordering: .relaxed),
            belowThreshold: counters.belowThreshold.load(ordering: .relaxed),
            splitterDeclined: counters.splitterDeclined.load(ordering: .relaxed),
            fallbacksAfterFailure: counters.fallbacksAfterFailure.load(ordering: .relaxed)
        )
    }

    @_spi(XRPCDecodeExperimental)
    public static func resetStatistics() {
        counters.parallelDecodes.store(0, ordering: .relaxed)
        counters.belowThreshold.store(0, ordering: .relaxed)
        counters.splitterDeclined.store(0, ordering: .relaxed)
        counters.fallbacksAfterFailure.store(0, ordering: .relaxed)
    }

    // MARK: - Decode entry points (called by generated code)
    //
    // Both overloads are kept unspecialized (one copy each, not one per output type): ~220 generated
    // endpoints call them, and the body only forwards to Foundation's already-generic
    // `JSONDecoder.decode`, so specialization would buy nothing but code size.

    /// Decodes `data` as `Output` with a fresh `JSONDecoder`, exactly as generated endpoints always have.
    ///
    /// - Throws: `CancellationError` if the current task is cancelled before decoding starts (when
    ///   ``Configuration/checksCancellationBeforeDecode`` is on); otherwise whatever
    ///   `JSONDecoder.decode(_:from:)` throws.
    #if compiler(>=6.2) && hasAttribute(concurrent)
        @concurrent
    #endif
    @_semantics("optimize.sil.specialize.generic.never")
    @inline(never)
    public static func decode<Output: Decodable & Sendable>(
        _: Output.Type,
        from data: Data,
        endpoint: String
    ) async throws -> Output {
        let configuration = effectiveConfiguration()
        if configuration.checksCancellationBeforeDecode {
            try Task.checkCancellation()
        }
        #if canImport(os)
            let interval = beginInterval(endpoint: endpoint, byteCount: data.count, parallel: false)
            defer { signposter.endInterval(intervalName, interval) }
        #endif
        return try JSONDecoder().decode(Output.self, from: data)
    }

    /// Overload chosen at compile time for outputs that conform to ``XRPCParallelArrayDecodable``.
    /// Identical to the general overload unless ``Configuration/parallelArrayDecoding`` is enabled.
    #if compiler(>=6.2) && hasAttribute(concurrent)
        @concurrent
    #endif
    @_semantics("optimize.sil.specialize.generic.never")
    @inline(never)
    public static func decode<Output: XRPCParallelArrayDecodable>(
        _: Output.Type,
        from data: Data,
        endpoint: String
    ) async throws -> Output {
        let configuration = effectiveConfiguration()
        if configuration.checksCancellationBeforeDecode {
            try Task.checkCancellation()
        }
        #if canImport(os)
            let interval = beginInterval(endpoint: endpoint, byteCount: data.count, parallel: configuration.parallelArrayDecoding)
            defer { signposter.endInterval(intervalName, interval) }
        #endif
        guard configuration.parallelArrayDecoding else {
            return try JSONDecoder().decode(Output.self, from: data)
        }
        return try await XRPCParallelArrayDecoder.decode(Output.self, from: data, configuration: configuration)
    }

    // MARK: - Generated-endpoint wrappers

    /// What every generated endpoint does with a 2xx JSON body: decode it, or log the failure and
    /// return `nil` (the endpoint still returns the response code). `CancellationError` propagates.
    ///
    /// The log line is the one generated endpoints always emitted
    /// (`Failed to decode successful response for <nsid>: <error>`); keeping the do/catch here instead of
    /// in ~220 generated functions also keeps their code size flat.
    #if compiler(>=6.2) && hasAttribute(concurrent)
        @concurrent
    #endif
    @_semantics("optimize.sil.specialize.generic.never")
    @inline(never)
    public static func decodeSuccessfulResponse<Output: Decodable & Sendable>(
        _: Output.Type,
        from data: Data,
        endpoint: String
    ) async throws -> Output? {
        do {
            return try await decode(Output.self, from: data, endpoint: endpoint)
        } catch let error as CancellationError {
            throw error
        } catch {
            LogManager.logError("Failed to decode successful response for \(endpoint): \(error)")
            return nil
        }
    }

    /// Overload chosen at compile time for ``XRPCParallelArrayDecodable`` outputs.
    #if compiler(>=6.2) && hasAttribute(concurrent)
        @concurrent
    #endif
    @_semantics("optimize.sil.specialize.generic.never")
    @inline(never)
    public static func decodeSuccessfulResponse<Output: XRPCParallelArrayDecodable>(
        _: Output.Type,
        from data: Data,
        endpoint: String
    ) async throws -> Output? {
        do {
            return try await decode(Output.self, from: data, endpoint: endpoint)
        } catch let error as CancellationError {
            throw error
        } catch {
            LogManager.logError("Failed to decode successful response for \(endpoint): \(error)")
            return nil
        }
    }

    // MARK: - Parallel bookkeeping hooks

    static func recordParallelDecode() {
        counters.parallelDecodes.wrappingAdd(1, ordering: .relaxed)
    }

    static func recordBelowThreshold() {
        counters.belowThreshold.wrappingAdd(1, ordering: .relaxed)
    }

    static func recordSplitterDeclined() {
        counters.splitterDeclined.wrappingAdd(1, ordering: .relaxed)
    }

    static func recordFallbackAfterFailure() {
        counters.fallbacksAfterFailure.wrappingAdd(1, ordering: .relaxed)
    }

    // MARK: - Signposts

    #if canImport(os)
        private static let signposter = OSSignposter(subsystem: "com.joshlacalamito.Petrel", category: .pointsOfInterest)
        private static let intervalName: StaticString = "XRPCDecode"

        @inline(__always)
        private static func beginInterval(endpoint: String, byteCount: Int, parallel: Bool) -> OSSignpostIntervalState {
            signposter.beginInterval(
                intervalName,
                id: signposter.makeSignpostID(),
                "\(endpoint, privacy: .public) bytes=\(byteCount) parallel=\(parallel)"
            )
        }
    #endif
}
