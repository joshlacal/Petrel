// Lexicon: 1, ID: place.stream.server.updateWebhook
// Update an existing webhook configuration.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamServerUpdateWebhookDefs {
    const val TYPE_IDENTIFIER = "place.stream.server.updateWebhook"
}

@Serializable
    data class PlaceStreamServerUpdateWebhookInput(
// The ID of the webhook to update.        @SerialName("id")
        val id: String,// The webhook URL where events will be sent.        @SerialName("url")
        val url: URI? = null,// The types of events this webhook should receive.        @SerialName("events")
        val events: List<String>? = null,// Whether this webhook should be active.        @SerialName("active")
        val active: Boolean? = null,// Text to prepend to webhook messages.        @SerialName("prefix")
        val prefix: String? = null,// Text to append to webhook messages.        @SerialName("suffix")
        val suffix: String? = null,// Text replacement rules for webhook messages.        @SerialName("rewrite")
        val rewrite: List<PlaceStreamServerDefsRewriteRule>? = null,// A user-friendly name for this webhook.        @SerialName("name")
        val name: String? = null,// A description of what this webhook is used for.        @SerialName("description")
        val description: String? = null,// Words to filter out from chat messages. Messages containing any of these words will not be forwarded.        @SerialName("muteWords")
        val muteWords: List<String>? = null    )

    @Serializable
    data class PlaceStreamServerUpdateWebhookOutput(
        @SerialName("webhook")
        val webhook: PlaceStreamServerDefsWebhook    )

sealed class PlaceStreamServerUpdateWebhookError(val name: String, val description: String?) {
        object WebhookNotFound: PlaceStreamServerUpdateWebhookError("WebhookNotFound", "The specified webhook was not found.")
        object Unauthorized: PlaceStreamServerUpdateWebhookError("Unauthorized", "The authenticated user does not have access to this webhook.")
        object InvalidUrl: PlaceStreamServerUpdateWebhookError("InvalidUrl", "The provided webhook URL is invalid or unreachable.")
        object DuplicateWebhook: PlaceStreamServerUpdateWebhookError("DuplicateWebhook", "A webhook with this URL already exists for this user.")
    }

/**
 * Update an existing webhook configuration.
 *
 * Endpoint: place.stream.server.updateWebhook
 */
suspend fun ATProtoClient.Place.Stream.Server.updateWebhook(
input: PlaceStreamServerUpdateWebhookInput): ATProtoResponse<PlaceStreamServerUpdateWebhookOutput> {
    val endpoint = "place.stream.server.updateWebhook"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
