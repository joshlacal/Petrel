//
//  IdentityCache.swift
//  Petrel
//

import Foundation

/// A cached value and the moment it was stored.
public struct IdentityCacheEntry<Value: Sendable>: Sendable {
    /// The cached value.
    public let value: Value
    /// When the value was fetched.
    public let storedAt: Date

    /// Creates an entry.
    public init(value: Value, storedAt: Date) {
        self.value = value
        self.storedAt = storedAt
    }
}

/// How long an ``IdentityResolver`` trusts cached results.
///
/// An entry younger than ``freshFor`` is returned without a network request. An older entry is
/// fetched again; if that fetch fails in transit (not with a definite "not found"), the old
/// entry is still served until it reaches ``maximumAge``, so a brief outage of a handle host or
/// the PLC directory does not take identities offline. An entry older than ``maximumAge`` is
/// never served.
public struct IdentityCachePolicy: Sendable, Equatable {
    /// How long an entry is served without re-resolving, in seconds.
    public var freshFor: TimeInterval
    /// The age, in seconds, past which an entry is never served.
    public var maximumAge: TimeInterval

    /// Creates a policy. The defaults, one hour and one day, match the reference implementation.
    public init(freshFor: TimeInterval = 60 * 60, maximumAge: TimeInterval = 24 * 60 * 60) {
        self.freshFor = freshFor
        self.maximumAge = max(maximumAge, freshFor)
    }

    /// One hour fresh, one day at most.
    public static let `default` = IdentityCachePolicy()
    /// Nothing is served from the cache.
    public static let disabled = IdentityCachePolicy(freshFor: 0, maximumAge: 0)
}

/// Storage for resolved DID documents and handle lookups.
///
/// The cache stores and returns entries; ``IdentityResolver`` decides whether an entry is still
/// usable from its ``IdentityCacheEntry/storedAt`` and the ``IdentityCachePolicy``. A stored
/// handle entry is the DID the handle pointed at, before bidirectional verification: the
/// resolver checks it against the DID document every time it is read, so a cache can never
/// make an unverified handle look verified.
///
/// ``InMemoryIdentityCache`` is the default. Implement this protocol to share a cache between
/// processes (Redis, a database).
public protocol IdentityCache: Sendable {
    /// The cached DID document for `did`, if any.
    func didDocument(for did: String) async -> IdentityCacheEntry<DIDDocument>?
    /// Stores `document` as the DID document of `did`.
    func setDIDDocument(_ document: DIDDocument, for did: String, storedAt: Date) async
    /// Removes the cached DID document of `did`.
    func removeDIDDocument(for did: String) async
    /// The DID the normalized `handle` last pointed at, if cached.
    func did(forHandle handle: String) async -> IdentityCacheEntry<String>?
    /// Stores `did` as the DID the normalized `handle` points at.
    func setDID(_ did: String, forHandle handle: String, storedAt: Date) async
    /// Removes the cached lookup of `handle`.
    func removeHandle(_ handle: String) async
    /// Removes every entry.
    func removeAll() async
}

/// An ``IdentityCache`` held in memory, bounded by entry count.
///
/// When a kind of entry (documents, handles) exceeds `capacity`, the oldest entries of that
/// kind are dropped.
public actor InMemoryIdentityCache: IdentityCache {
    private let capacity: Int
    private var documents: [String: IdentityCacheEntry<DIDDocument>] = [:]
    private var handles: [String: IdentityCacheEntry<String>] = [:]

    /// Creates a cache.
    /// - Parameter capacity: The largest number of DID documents, and of handles, to keep.
    public init(capacity: Int = 1024) {
        self.capacity = max(capacity, 1)
    }

    public func didDocument(for did: String) -> IdentityCacheEntry<DIDDocument>? {
        documents[did]
    }

    public func setDIDDocument(_ document: DIDDocument, for did: String, storedAt: Date) {
        documents[did] = IdentityCacheEntry(value: document, storedAt: storedAt)
        Self.trim(&documents, to: capacity)
    }

    public func removeDIDDocument(for did: String) {
        documents[did] = nil
    }

    public func did(forHandle handle: String) -> IdentityCacheEntry<String>? {
        handles[handle]
    }

    public func setDID(_ did: String, forHandle handle: String, storedAt: Date) {
        handles[handle] = IdentityCacheEntry(value: did, storedAt: storedAt)
        Self.trim(&handles, to: capacity)
    }

    public func removeHandle(_ handle: String) {
        handles[handle] = nil
    }

    public func removeAll() {
        documents.removeAll()
        handles.removeAll()
    }

    private static func trim<Value>(_ entries: inout [String: IdentityCacheEntry<Value>], to capacity: Int) {
        guard entries.count > capacity else { return }
        // Drop an extra eighth so a full cache does not sort on every insertion.
        let overflow = entries.count - capacity + capacity / 8
        let oldest = entries.sorted { $0.value.storedAt < $1.value.storedAt }.prefix(overflow)
        for (key, _) in oldest {
            entries[key] = nil
        }
    }
}
