// Lexicon: 1, ID: app.bsky.graph.getStarterPacksWithMembership
// Enumerates the starter packs created by the session user, and includes membership information about `actor` in those starter packs. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphGetstarterpackswithmembership {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getStarterPacksWithMembership"

    @Serializable
    data class Parameters(
// The account (actor) to check for membership.        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("starterPacksWithMembership")
        val starterPacksWithMembership: List<Starterpackwithmembership>    )

        /**
     * A starter pack and an optional list item indicating membership of a target user to that starter pack.
     */
    @Serializable
    data class Starterpackwithmembership(
        @SerialName("starterPack")
        val starterPack: AppBskyGraphDefs.Starterpackview,        @SerialName("listItem")
        val listItem: AppBskyGraphDefs.Listitemview?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#starterpackwithmembership"
        }
    }

}

/**
 * Enumerates the starter packs created by the session user, and includes membership information about `actor` in those starter packs. Requires auth.
 *
 * Endpoint: app.bsky.graph.getStarterPacksWithMembership
 */
suspend fun ATProtoClient.App.Bsky.Graph.getstarterpackswithmembership(
parameters: AppBskyGraphGetstarterpackswithmembership.Parameters): ATProtoResponse<AppBskyGraphGetstarterpackswithmembership.Output> {
    val endpoint = "app.bsky.graph.getStarterPacksWithMembership"

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
