// Lexicon: 1, ID: place.stream.server.listWebhooks
// List webhooks for the authenticated user.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamServerListWebhooksDefs {
    const val TYPE_IDENTIFIER = "place.stream.server.listWebhooks"
}

@Serializable
    data class PlaceStreamServerListWebhooksParameters(
// The number of webhooks to return.        @SerialName("limit")
        val limit: Int? = null,// An optional cursor for pagination.        @SerialName("cursor")
        val cursor: String? = null,// Filter webhooks by active status.        @SerialName("active")
        val active: Boolean? = null,// Filter webhooks that handle this event type.        @SerialName("event")
        val event: String? = null    )

    @Serializable
    data class PlaceStreamServerListWebhooksOutput(
        @SerialName("webhooks")
        val webhooks: List<PlaceStreamServerDefsWebhook>,// A cursor for pagination, if there are more results.        @SerialName("cursor")
        val cursor: String? = null    )

sealed class PlaceStreamServerListWebhooksError(val name: String, val description: String?) {
        object InvalidCursor: PlaceStreamServerListWebhooksError("InvalidCursor", "The provided cursor is invalid or expired.")
    }

/**
 * List webhooks for the authenticated user.
 *
 * Endpoint: place.stream.server.listWebhooks
 */
suspend fun ATProtoClient.Place.Stream.Server.listWebhooks(
parameters: PlaceStreamServerListWebhooksParameters): ATProtoResponse<PlaceStreamServerListWebhooksOutput> {
    val endpoint = "place.stream.server.listWebhooks"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
