// Lexicon: 1, ID: app.bsky.actor.putPreferences
// Set the private preferences attached to the account.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyActorPutpreferences {
    const val TYPE_IDENTIFIER = "app.bsky.actor.putPreferences"

    @Serializable
    data class Input(
        @SerialName("preferences")
        val preferences: AppBskyActorDefs.Preferences    )

}

/**
 * Set the private preferences attached to the account.
 *
 * Endpoint: app.bsky.actor.putPreferences
 */
suspend fun ATProtoClient.App.Bsky.Actor.putpreferences(
input: AppBskyActorPutpreferences.Input): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.actor.putPreferences"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
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
