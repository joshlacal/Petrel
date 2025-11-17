// Lexicon: 1, ID: app.bsky.unspecced.getTaggedSuggestions
// Get a list of suggestions (feeds and users) tagged with categories
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyUnspeccedGettaggedsuggestions {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getTaggedSuggestions"

    @Serializable
    data class Parameters(
    )

        @Serializable
    data class Output(
        @SerialName("suggestions")
        val suggestions: List<Suggestion>    )

        @Serializable
    data class Suggestion(
        @SerialName("tag")
        val tag: String,        @SerialName("subjectType")
        val subjectType: String,        @SerialName("subject")
        val subject: URI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#suggestion"
        }
    }

}

/**
 * Get a list of suggestions (feeds and users) tagged with categories
 *
 * Endpoint: app.bsky.unspecced.getTaggedSuggestions
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.gettaggedsuggestions(
parameters: AppBskyUnspeccedGettaggedsuggestions.Parameters): ATProtoResponse<AppBskyUnspeccedGettaggedsuggestions.Output> {
    val endpoint = "app.bsky.unspecced.getTaggedSuggestions"

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
