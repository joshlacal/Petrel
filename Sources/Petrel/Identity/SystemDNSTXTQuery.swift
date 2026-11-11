//
//  SystemDNSTXTQuery.swift
//  Petrel
//

#if canImport(Darwin)
    import dnssd
    import Foundation

    /// One DNS TXT query through the system resolver (`mDNSResponder`) on Apple platforms.
    ///
    /// The query asks for intermediate results, so a name that does not exist, or that has no
    /// TXT record, is answered at once with "no such record". Without that flag the system
    /// resolver reports only positive answers and a missing record costs the whole timeout,
    /// which is the usual case for a handle that is published over HTTPS instead of DNS.
    final class SystemDNSTXTQuery: @unchecked Sendable {
        /// A failure reported by the system resolver, with its `DNSServiceErrorType` code.
        struct Failure: Error, CustomStringConvertible {
            let code: Int32
            var description: String { "system DNS query failed (\(code))" }
        }

        private enum State {
            case idle
            case waiting(CheckedContinuation<[String], Error>)
            /// Finished, possibly before the caller's continuation existed (an early cancel).
            case finished(Result<[String], Error>)
        }

        private let queue = DispatchQueue(label: "petrel.identity.dns-txt")
        private let lock = NSLock()
        private var state = State.idle
        /// Touched only on `queue`.
        private var serviceRef: DNSServiceRef?
        private var retainedContext: Unmanaged<SystemDNSTXTQuery>?
        private var records: [String] = []

        /// The TXT record values at `name`, each with its character-strings joined; empty when
        /// the name or the record type does not exist.
        static func run(name: String) async throws -> [String] {
            let query = SystemDNSTXTQuery()
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    query.start(name: name, continuation: continuation)
                }
            } onCancel: {
                query.finish(.failure(CancellationError()))
            }
        }

        private func start(name: String, continuation: CheckedContinuation<[String], Error>) {
            let early = lock.withLock { () -> Result<[String], Error>? in
                if case let .finished(result) = state { return result }
                state = .waiting(continuation)
                return nil
            }
            if let early {
                continuation.resume(with: early)
                return
            }
            queue.async { [self] in
                // The caller may have been cancelled between `start` and this block.
                guard lock.withLock({ if case .waiting = state { true } else { false } }) else { return }
                let context = Unmanaged.passRetained(self)
                retainedContext = context
                var ref: DNSServiceRef?
                let flags = DNSServiceFlags(kDNSServiceFlagsReturnIntermediates | kDNSServiceFlagsTimeout)
                let status = DNSServiceQueryRecord(
                    &ref, flags, 0, name,
                    UInt16(kDNSServiceType_TXT), UInt16(kDNSServiceClass_IN),
                    Self.reply, context.toOpaque()
                )
                guard status == kDNSServiceErr_NoError, let ref else {
                    finish(.failure(Failure(code: status)))
                    return
                }
                serviceRef = ref
                let queueStatus = DNSServiceSetDispatchQueue(ref, queue)
                if queueStatus != kDNSServiceErr_NoError {
                    finish(.failure(Failure(code: queueStatus)))
                }
            }
        }

        private static let reply: DNSServiceQueryRecordReply = { _, flags, _, errorCode, _, recordType, _, length, data, _, context in
            guard let context else { return }
            Unmanaged<SystemDNSTXTQuery>.fromOpaque(context).takeUnretainedValue()
                .handle(flags: flags, errorCode: errorCode, recordType: recordType, length: length, data: data)
        }

        /// Runs on `queue`.
        private func handle(
            flags: DNSServiceFlags,
            errorCode: DNSServiceErrorType,
            recordType: UInt16,
            length: UInt16,
            data: UnsafeRawPointer?
        ) {
            let moreComing = flags & DNSServiceFlags(kDNSServiceFlagsMoreComing) != 0
            switch Int(errorCode) {
            case kDNSServiceErr_NoError:
                // Intermediate answers (a CNAME on the way to the TXT record) are not the answer.
                guard recordType == UInt16(kDNSServiceType_TXT) else { return }
                if flags & DNSServiceFlags(kDNSServiceFlagsAdd) != 0, let data {
                    records.append(Self.joinedCharacterStrings(UnsafeRawBufferPointer(start: data, count: Int(length))))
                }
                if !moreComing {
                    finish(.success(records))
                }
            case kDNSServiceErr_NoSuchRecord, kDNSServiceErr_NoSuchName:
                if !moreComing {
                    finish(.success(records))
                }
            default:
                finish(.failure(Failure(code: errorCode)))
            }
        }

        /// TXT RDATA is a sequence of length-prefixed character-strings; a value longer than 255
        /// bytes is split across several, which belong together.
        static func joinedCharacterStrings(_ bytes: UnsafeRawBufferPointer) -> String {
            var joined: [UInt8] = []
            var index = 0
            while index < bytes.count {
                let count = Int(bytes[index])
                let start = index + 1
                let end = min(start + count, bytes.count)
                joined.append(contentsOf: bytes[start ..< end])
                index = end
            }
            return String(decoding: joined, as: UTF8.self)
        }

        /// Resumes the caller once and releases the query. Safe from any thread.
        private func finish(_ result: Result<[String], Error>) {
            let continuation = lock.withLock { () -> CheckedContinuation<[String], Error>? in
                switch state {
                case .finished:
                    return nil
                case .idle:
                    state = .finished(result)
                    return nil
                case let .waiting(continuation):
                    state = .finished(result)
                    return continuation
                }
            }
            continuation?.resume(with: result)
            // The service reference is torn down on the queue its callbacks run on. This block
            // is a no-op when the query never started or was already torn down.
            queue.async { [self] in
                if let serviceRef {
                    DNSServiceRefDeallocate(serviceRef)
                }
                serviceRef = nil
                retainedContext?.release()
                retainedContext = nil
            }
        }
    }
#endif
