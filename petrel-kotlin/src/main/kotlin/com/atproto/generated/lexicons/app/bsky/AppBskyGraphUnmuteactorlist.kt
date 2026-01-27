// Lexicon: 1, ID: app.bsky.graph.unmuteActorList
// Unmutes the specified list of accounts. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphUnmuteActorListDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.unmuteActorList"
}

@Serializable
    data class AppBskyGraphUnmuteActorListInput(
        @SerialName("list")
        val list: ATProtocolURI    )

/**
 * Unmutes the specified list of accounts. Requires auth.
 *
 * Endpoint: app.bsky.graph.unmuteActorList
 */
suspend fun ATProtoClient.App.Bsky.Graph.unmuteActorList(
input: AppBskyGraphUnmuteActorListInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.graph.unmuteActorList"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
