package com.atproto.auth.gateway

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Persistent storage for confidential-gateway session IDs, keyed by DID.
 *
 * Mirrors the iOS `KeychainStorage` methods that back [ConfidentialGatewayStrategy]:
 *   - `saveGatewaySession(_:for:)`
 *   - `getGatewaySession(for:)`
 *   - `deleteGatewaySession(for:)`
 *
 * Android implementations should back this with `EncryptedSharedPreferences`
 * (or Android Keystore) so the session UUID is encrypted at rest. The SDK
 * stays abstract; the app layer provides the concrete implementation.
 */
interface GatewaySessionStorage {
    /** Save the gateway session id for the given DID (overwrites any existing value). */
    suspend fun saveSession(did: String, sessionId: String)

    /** Retrieve the gateway session id for the given DID, or null if none exists. */
    suspend fun getSession(did: String): String?

    /** Remove the gateway session id for the given DID. Idempotent. */
    suspend fun deleteSession(did: String)

    /** Return every DID that currently has a stored gateway session. */
    suspend fun getAllDids(): List<String>
}

/**
 * Tracks which account is "current" across the SDK — the analogue of iOS's
 * `AccountManaging.getCurrentAccount()` / `setCurrentAccount(did:)`.
 *
 * Android apps typically back this with `EncryptedSharedPreferences` so the
 * selection survives process death.
 */
interface CurrentAccount {
    suspend fun getCurrentDid(): String?
    suspend fun setCurrentDid(did: String?)
}

/**
 * In-memory reference implementation of both [GatewaySessionStorage] and
 * [CurrentAccount]. Intended for tests and for clients that don't need
 * persistence. NOT suitable for production use — sessions are lost on
 * process restart.
 */
class InMemoryGatewaySessionStorage : GatewaySessionStorage, CurrentAccount {
    private val mutex = Mutex()
    private val sessions = mutableMapOf<String, String>()
    private var currentDid: String? = null

    override suspend fun saveSession(did: String, sessionId: String) = mutex.withLock {
        sessions[did] = sessionId
    }

    override suspend fun getSession(did: String): String? = mutex.withLock {
        sessions[did]
    }

    override suspend fun deleteSession(did: String) = mutex.withLock {
        sessions.remove(did)
        Unit
    }

    override suspend fun getAllDids(): List<String> = mutex.withLock {
        sessions.keys.toList()
    }

    override suspend fun getCurrentDid(): String? = mutex.withLock { currentDid }

    override suspend fun setCurrentDid(did: String?) = mutex.withLock {
        currentDid = did
    }
}
