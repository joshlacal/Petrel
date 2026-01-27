// Lexicon: 1, ID: app.bsky.actor.getPreferences
// Get private preferences attached to the current account. Expected use is synchronization between multiple devices, and import/export during account migration. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyActorGetPreferencesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.actor.getPreferences"
}

@Serializable
    class AppBskyActorGetPreferencesParameters

    @Serializable
    data class AppBskyActorGetPreferencesOutput(
        @SerialName("preferences")
        val preferences: AppBskyActorDefsPreferences    )

/**
 * Get private preferences attached to the current account. Expected use is synchronization between multiple devices, and import/export during account migration. Requires auth.
 *
 * Endpoint: app.bsky.actor.getPreferences
 */
suspend fun ATProtoClient.App.Bsky.Actor.getPreferences(
parameters: AppBskyActorGetPreferencesParameters): ATProtoResponse<AppBskyActorGetPreferencesOutput> {
    val endpoint = "app.bsky.actor.getPreferences"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
