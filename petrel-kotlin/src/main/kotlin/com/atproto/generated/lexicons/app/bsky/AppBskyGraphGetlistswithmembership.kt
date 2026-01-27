// Lexicon: 1, ID: app.bsky.graph.getListsWithMembership
// Enumerates the lists created by the session user, and includes membership information about `actor` in those lists. Only supports curation and moderation lists (no reference lists, used in starter packs). Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphGetListsWithMembershipDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getListsWithMembership"
}

    /**
     * A list and an optional list item indicating membership of a target user to that list.
     */
    @Serializable
    data class AppBskyGraphGetListsWithMembershipListWithMembership(
        @SerialName("list")
        val list: AppBskyGraphDefsListView,        @SerialName("listItem")
        val listItem: AppBskyGraphDefsListItemView?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyGraphGetListsWithMembershipListWithMembership"
        }
    }

@Serializable
    data class AppBskyGraphGetListsWithMembershipParameters(
// The account (actor) to check for membership.        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null,// Optional filter by list purpose. If not specified, all supported types are returned.        @SerialName("purposes")
        val purposes: List<String>? = null    )

    @Serializable
    data class AppBskyGraphGetListsWithMembershipOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("listsWithMembership")
        val listsWithMembership: List<AppBskyGraphGetListsWithMembershipListWithMembership>    )

/**
 * Enumerates the lists created by the session user, and includes membership information about `actor` in those lists. Only supports curation and moderation lists (no reference lists, used in starter packs). Requires auth.
 *
 * Endpoint: app.bsky.graph.getListsWithMembership
 */
suspend fun ATProtoClient.App.Bsky.Graph.getListsWithMembership(
parameters: AppBskyGraphGetListsWithMembershipParameters): ATProtoResponse<AppBskyGraphGetListsWithMembershipOutput> {
    val endpoint = "app.bsky.graph.getListsWithMembership"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
