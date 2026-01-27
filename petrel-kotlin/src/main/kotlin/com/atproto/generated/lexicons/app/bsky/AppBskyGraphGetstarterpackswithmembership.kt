// Lexicon: 1, ID: app.bsky.graph.getStarterPacksWithMembership
// Enumerates the starter packs created by the session user, and includes membership information about `actor` in those starter packs. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphGetStarterPacksWithMembershipDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getStarterPacksWithMembership"
}

    /**
     * A starter pack and an optional list item indicating membership of a target user to that starter pack.
     */
    @Serializable
    data class AppBskyGraphGetStarterPacksWithMembershipStarterPackWithMembership(
        @SerialName("starterPack")
        val starterPack: AppBskyGraphDefsStarterPackView,        @SerialName("listItem")
        val listItem: AppBskyGraphDefsListItemView?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyGraphGetStarterPacksWithMembershipStarterPackWithMembership"
        }
    }

@Serializable
    data class AppBskyGraphGetStarterPacksWithMembershipParameters(
// The account (actor) to check for membership.        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyGraphGetStarterPacksWithMembershipOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("starterPacksWithMembership")
        val starterPacksWithMembership: List<AppBskyGraphGetStarterPacksWithMembershipStarterPackWithMembership>    )

/**
 * Enumerates the starter packs created by the session user, and includes membership information about `actor` in those starter packs. Requires auth.
 *
 * Endpoint: app.bsky.graph.getStarterPacksWithMembership
 */
suspend fun ATProtoClient.App.Bsky.Graph.getStarterPacksWithMembership(
parameters: AppBskyGraphGetStarterPacksWithMembershipParameters): ATProtoResponse<AppBskyGraphGetStarterPacksWithMembershipOutput> {
    val endpoint = "app.bsky.graph.getStarterPacksWithMembership"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
