// Lexicon: 1, ID: app.bsky.actor.getPreferences
// Get private preferences attached to the current account. Expected use is synchronization between multiple devices, and import/export during account migration. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyActorGetpreferences {
    const val TYPE_IDENTIFIER = "app.bsky.actor.getPreferences"

    @Serializable
    data class Parameters(
    )

        @Serializable
    data class Output(
        @SerialName("preferences")
        val preferences: AppBskyActorDefs.Preferences    )

}

/**
 * Get private preferences attached to the current account. Expected use is synchronization between multiple devices, and import/export during account migration. Requires auth.
 *
 * Endpoint: app.bsky.actor.getPreferences
 */
suspend fun ATProtoClient.App.Bsky.Actor.getpreferences(
parameters: AppBskyActorGetpreferences.Parameters): ATProtoResponse<AppBskyActorGetpreferences.Output> {
    val endpoint = "app.bsky.actor.getPreferences"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
