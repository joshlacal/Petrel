// Lexicon: 1, ID: app.bsky.actor.getSuggestions
// Get a list of suggested actors. Expected use is discovery of accounts to follow during new account onboarding.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyActorGetsuggestions {
    const val TYPE_IDENTIFIER = "app.bsky.actor.getSuggestions"

    @Serializable
    data class Parameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("actors")
        val actors: List<AppBskyActorDefs.Profileview>,// Snowflake for this recommendation, use when submitting recommendation events.        @SerialName("recId")
        val recId: Int? = null    )

}

/**
 * Get a list of suggested actors. Expected use is discovery of accounts to follow during new account onboarding.
 *
 * Endpoint: app.bsky.actor.getSuggestions
 */
suspend fun ATProtoClient.App.Bsky.Actor.getsuggestions(
parameters: AppBskyActorGetsuggestions.Parameters): ATProtoResponse<AppBskyActorGetsuggestions.Output> {
    val endpoint = "app.bsky.actor.getSuggestions"

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
