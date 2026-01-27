// Lexicon: 1, ID: app.bsky.graph.getList
// Gets a 'view' (with additional context) of a specified list.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphGetListDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getList"
}

@Serializable
    data class AppBskyGraphGetListParameters(
// Reference (AT-URI) of the list record to hydrate.        @SerialName("list")
        val list: ATProtocolURI,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyGraphGetListOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("list")
        val list: AppBskyGraphDefsListView,        @SerialName("items")
        val items: List<AppBskyGraphDefsListItemView>    )

/**
 * Gets a 'view' (with additional context) of a specified list.
 *
 * Endpoint: app.bsky.graph.getList
 */
suspend fun ATProtoClient.App.Bsky.Graph.getList(
parameters: AppBskyGraphGetListParameters): ATProtoResponse<AppBskyGraphGetListOutput> {
    val endpoint = "app.bsky.graph.getList"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
