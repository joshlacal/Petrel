// Lexicon: 1, ID: app.bsky.actor.putPreferences
// Set the private preferences attached to the account.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyActorPutPreferencesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.actor.putPreferences"
}

@Serializable
    data class AppBskyActorPutPreferencesInput(
        @SerialName("preferences")
        val preferences: AppBskyActorDefsPreferences    )

/**
 * Set the private preferences attached to the account.
 *
 * Endpoint: app.bsky.actor.putPreferences
 */
suspend fun ATProtoClient.App.Bsky.Actor.putPreferences(
input: AppBskyActorPutPreferencesInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.actor.putPreferences"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
