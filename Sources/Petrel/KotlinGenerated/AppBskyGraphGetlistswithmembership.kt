// Lexicon: 1, ID: app.bsky.graph.getListsWithMembership
// Enumerates the lists created by the session user, and includes membership information about `actor` in those lists. Only supports curation and moderation lists (no reference lists, used in starter packs). Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphGetlistswithmembership {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getListsWithMembership"

    @Serializable
    data class Parameters(
// The account (actor) to check for membership.        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null,// Optional filter by list purpose. If not specified, all supported types are returned.        @SerialName("purposes")
        val purposes: List<String>? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("listsWithMembership")
        val listsWithMembership: List<Listwithmembership>    )

        /**
     * A list and an optional list item indicating membership of a target user to that list.
     */
    @Serializable
    data class Listwithmembership(
        @SerialName("list")
        val list: AppBskyGraphDefs.Listview,        @SerialName("listItem")
        val listItem: AppBskyGraphDefs.Listitemview?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#listwithmembership"
        }
    }

}

/**
 * Enumerates the lists created by the session user, and includes membership information about `actor` in those lists. Only supports curation and moderation lists (no reference lists, used in starter packs). Requires auth.
 *
 * Endpoint: app.bsky.graph.getListsWithMembership
 */
suspend fun ATProtoClient.App.Bsky.Graph.getlistswithmembership(
parameters: AppBskyGraphGetlistswithmembership.Parameters): ATProtoResponse<AppBskyGraphGetlistswithmembership.Output> {
    val endpoint = "app.bsky.graph.getListsWithMembership"

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
