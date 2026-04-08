// Lexicon: 1, ID: app.bsky.actor.getSuggestions
// Get a list of suggested actors. Expected use is discovery of accounts to follow during new account onboarding.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyActorGetSuggestionsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.actor.getSuggestions"
}

@Serializable
    data class AppBskyActorGetSuggestionsParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyActorGetSuggestionsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("actors")
        val actors: List<AppBskyActorDefsProfileView>,// Snowflake for this recommendation, use when submitting recommendation events.        @SerialName("recId")
        val recId: Int? = null    )

/**
 * Get a list of suggested actors. Expected use is discovery of accounts to follow during new account onboarding.
 *
 * Endpoint: app.bsky.actor.getSuggestions
 */
suspend fun ATProtoClient.App.Bsky.Actor.getSuggestions(
parameters: AppBskyActorGetSuggestionsParameters): ATProtoResponse<AppBskyActorGetSuggestionsOutput> {
    val endpoint = "app.bsky.actor.getSuggestions"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
