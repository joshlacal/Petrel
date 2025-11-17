// Lexicon: 1, ID: app.bsky.graph.getList
// Gets a 'view' (with additional context) of a specified list.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphGetlist {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getList"

    @Serializable
    data class Parameters(
// Reference (AT-URI) of the list record to hydrate.        @SerialName("list")
        val list: ATProtocolURI,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("list")
        val list: AppBskyGraphDefs.Listview,        @SerialName("items")
        val items: List<AppBskyGraphDefs.Listitemview>    )

}

/**
 * Gets a 'view' (with additional context) of a specified list.
 *
 * Endpoint: app.bsky.graph.getList
 */
suspend fun ATProtoClient.App.Bsky.Graph.getlist(
parameters: AppBskyGraphGetlist.Parameters): ATProtoResponse<AppBskyGraphGetlist.Output> {
    val endpoint = "app.bsky.graph.getList"

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
