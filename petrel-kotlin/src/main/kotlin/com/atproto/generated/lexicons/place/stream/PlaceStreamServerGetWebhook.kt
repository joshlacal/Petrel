// Lexicon: 1, ID: place.stream.server.getWebhook
// Get details for a specific webhook.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamServerGetWebhookDefs {
    const val TYPE_IDENTIFIER = "place.stream.server.getWebhook"
}

@Serializable
    data class PlaceStreamServerGetWebhookParameters(
// The ID of the webhook to retrieve.        @SerialName("id")
        val id: String    )

    @Serializable
    data class PlaceStreamServerGetWebhookOutput(
        @SerialName("webhook")
        val webhook: PlaceStreamServerDefsWebhook    )

sealed class PlaceStreamServerGetWebhookError(val name: String, val description: String?) {
        object WebhookNotFound: PlaceStreamServerGetWebhookError("WebhookNotFound", "The specified webhook was not found.")
        object Unauthorized: PlaceStreamServerGetWebhookError("Unauthorized", "The authenticated user does not have access to this webhook.")
    }

/**
 * Get details for a specific webhook.
 *
 * Endpoint: place.stream.server.getWebhook
 */
suspend fun ATProtoClient.Place.Stream.Server.getWebhook(
parameters: PlaceStreamServerGetWebhookParameters): ATProtoResponse<PlaceStreamServerGetWebhookOutput> {
    val endpoint = "place.stream.server.getWebhook"

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
