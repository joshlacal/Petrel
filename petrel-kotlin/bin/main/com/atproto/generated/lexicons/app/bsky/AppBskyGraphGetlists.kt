// Lexicon: 1, ID: app.bsky.graph.getLists
// Enumerates the lists created by a specified account (actor).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphGetListsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getLists"
}

@Serializable
    data class AppBskyGraphGetListsParameters(
// The account (actor) to enumerate lists from.        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null,// Optional filter by list purpose. If not specified, all supported types are returned.        @SerialName("purposes")
        val purposes: List<String>? = null    )

    @Serializable
    data class AppBskyGraphGetListsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("lists")
        val lists: List<AppBskyGraphDefsListView>    )

/**
 * Enumerates the lists created by a specified account (actor).
 *
 * Endpoint: app.bsky.graph.getLists
 */
suspend fun ATProtoClient.App.Bsky.Graph.getLists(
parameters: AppBskyGraphGetListsParameters): ATProtoResponse<AppBskyGraphGetListsOutput> {
    val endpoint = "app.bsky.graph.getLists"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
