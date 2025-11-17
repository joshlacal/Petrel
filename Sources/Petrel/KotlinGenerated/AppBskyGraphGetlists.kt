// Lexicon: 1, ID: app.bsky.graph.getLists
// Enumerates the lists created by a specified account (actor).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphGetlists {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getLists"

    @Serializable
    data class Parameters(
// The account (actor) to enumerate lists from.        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null,// Optional filter by list purpose. If not specified, all supported types are returned.        @SerialName("purposes")
        val purposes: List<String>? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("lists")
        val lists: List<AppBskyGraphDefs.Listview>    )

}

/**
 * Enumerates the lists created by a specified account (actor).
 *
 * Endpoint: app.bsky.graph.getLists
 */
suspend fun ATProtoClient.App.Bsky.Graph.getlists(
parameters: AppBskyGraphGetlists.Parameters): ATProtoResponse<AppBskyGraphGetlists.Output> {
    val endpoint = "app.bsky.graph.getLists"

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
