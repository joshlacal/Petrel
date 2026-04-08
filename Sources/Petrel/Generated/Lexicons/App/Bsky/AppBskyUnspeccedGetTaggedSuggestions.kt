// Lexicon: 1, ID: app.bsky.unspecced.getTaggedSuggestions
// Get a list of suggestions (feeds and users) tagged with categories
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetTaggedSuggestionsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getTaggedSuggestions"
}

    @Serializable
    data class AppBskyUnspeccedGetTaggedSuggestionsSuggestion(
        @SerialName("tag")
        val tag: String,        @SerialName("subjectType")
        val subjectType: String,        @SerialName("subject")
        val subject: URI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyUnspeccedGetTaggedSuggestionsSuggestion"
        }
    }

@Serializable
    class AppBskyUnspeccedGetTaggedSuggestionsParameters

    @Serializable
    data class AppBskyUnspeccedGetTaggedSuggestionsOutput(
        @SerialName("suggestions")
        val suggestions: List<AppBskyUnspeccedGetTaggedSuggestionsSuggestion>    )

/**
 * Get a list of suggestions (feeds and users) tagged with categories
 *
 * Endpoint: app.bsky.unspecced.getTaggedSuggestions
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getTaggedSuggestions(
parameters: AppBskyUnspeccedGetTaggedSuggestionsParameters): ATProtoResponse<AppBskyUnspeccedGetTaggedSuggestionsOutput> {
    val endpoint = "app.bsky.unspecced.getTaggedSuggestions"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
