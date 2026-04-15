package com.atproto.client

import com.atproto.auth.gateway.ConfidentialGatewayStrategy
import com.atproto.auth.gateway.CurrentAccount
import com.atproto.auth.gateway.GatewayCallbackResult
import com.atproto.auth.gateway.GatewaySessionStorage
import java.util.Collections
import java.util.WeakHashMap

/**
 * Extension wiring that attaches a [ConfidentialGatewayStrategy] to an
 * [ATProtoClient] without requiring changes to the generator template.
 *
 * Kotlin extension functions can't add fields to a class, so the
 * strategy-per-client mapping lives in a synchronized [WeakHashMap]. Entries
 * are removed automatically when their owning [ATProtoClient] is garbage
 * collected.
 *
 * The old inline `createGatewayLoginUrl` / `handleGatewayCallback` /
 * `restoreGatewaySession` / `clearGatewaySession` / `currentGatewaySessionId` /
 * `gatewayLogout` methods on [ATProtoClient] (emitted by
 * `Generator/templates/kotlin/KotlinClientMain.jinja`) remain for source
 * compatibility, but Android callers should migrate to the strategy-based
 * API exposed here. See the report in `wip/kotlin-gateway-strategy` for
 * follow-up template cleanup.
 */
private val strategies: MutableMap<ATProtoClient, ConfidentialGatewayStrategy> =
    Collections.synchronizedMap(WeakHashMap())

/**
 * Install a [ConfidentialGatewayStrategy] on this client.
 *
 * @param gatewayBaseUrl Root URL of the confidential gateway (nest), e.g.
 *                       `https://api.catbird.blue`. Must NOT end in `/xrpc`.
 * @param storage        Persistent store for gateway session UUIDs (per-DID).
 *                       Android apps should back this with
 *                       `EncryptedSharedPreferences`.
 * @param currentAccount Tracks which DID is the "current" account.
 *
 * Replaces an existing strategy on this client, if any.
 */
fun ATProtoClient.configureGateway(
    gatewayBaseUrl: String,
    storage: GatewaySessionStorage,
    currentAccount: CurrentAccount,
): ConfidentialGatewayStrategy {
    // Close any previously-installed strategy so its ktor engine is released.
    strategies.remove(this)?.close()

    val strategy = ConfidentialGatewayStrategy(
        gatewayBaseUrl = gatewayBaseUrl,
        storage = storage,
        currentAccount = currentAccount,
        networkService = networkService,
    )
    strategies[this] = strategy
    setAuthMode(AuthMode.Gateway)
    return strategy
}

/** The gateway strategy previously installed via [configureGateway], or `null`. */
val ATProtoClient.gatewayStrategy: ConfidentialGatewayStrategy?
    get() = strategies[this]

private fun ATProtoClient.requireGateway(): ConfidentialGatewayStrategy =
    gatewayStrategy
        ?: throw IllegalStateException(
            "Gateway not configured; call ATProtoClient.configureGateway(...) first",
        )

// --------------------------------------------------------------------
// High-level, strongly-typed facade.
//
// Prefer these over the (now-deprecated) methods emitted by the generator
// template — they go through the strategy actor, so session bookkeeping,
// 401 classification, and per-DID storage all happen in one place.
// --------------------------------------------------------------------

/** See [ConfidentialGatewayStrategy.startOAuthFlow]. */
suspend fun ATProtoClient.gatewayStartOAuthFlow(identifier: String? = null): String =
    requireGateway().startOAuthFlow(identifier)

/** See [ConfidentialGatewayStrategy.startOAuthFlowForSignUp]. */
suspend fun ATProtoClient.gatewayStartOAuthFlowForSignUp(pdsUrl: String? = null): String =
    requireGateway().startOAuthFlowForSignUp(pdsUrl)

/** See [ConfidentialGatewayStrategy.handleOAuthCallback]. */
suspend fun ATProtoClient.gatewayHandleCallback(callbackUrl: String): GatewayCallbackResult =
    requireGateway().handleOAuthCallback(callbackUrl)

/** See [ConfidentialGatewayStrategy.restoreSession]. */
suspend fun ATProtoClient.gatewayRestoreSession(did: String): String? =
    requireGateway().restoreSession(did)

/** See [ConfidentialGatewayStrategy.logout]. */
suspend fun ATProtoClient.gatewayLogoutViaStrategy() {
    requireGateway().logout()
}

/** See [ConfidentialGatewayStrategy.tokensExist]. */
suspend fun ATProtoClient.gatewayTokensExist(): Boolean =
    requireGateway().tokensExist()
