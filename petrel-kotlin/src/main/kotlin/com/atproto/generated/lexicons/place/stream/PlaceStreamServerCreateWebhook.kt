// Lexicon: 1, ID: place.stream.server.createWebhook
// Create a new webhook for receiving Streamplace events.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamServerCreateWebhookDefs {
    const val TYPE_IDENTIFIER = "place.stream.server.createWebhook"
}

@Serializable
    data class PlaceStreamServerCreateWebhookInput(
// The webhook URL where events will be sent.        @SerialName("url")
        val url: URI,// The types of events this webhook should receive.        @SerialName("events")
        val events: List<String>,// Whether this webhook should be active upon creation.        @SerialName("active")
        val active: Boolean? = null,// Text to prepend to webhook messages.        @SerialName("prefix")
        val prefix: String? = null,// Text to append to webhook messages.        @SerialName("suffix")
        val suffix: String? = null,// Text replacement rules for webhook messages.        @SerialName("rewrite")
        val rewrite: List<PlaceStreamServerDefsRewriteRule>? = null,// A user-friendly name for this webhook.        @SerialName("name")
        val name: String? = null,// A description of what this webhook is used for.        @SerialName("description")
        val description: String? = null,// Words to filter out from chat messages. Messages containing any of these words will not be forwarded.        @SerialName("muteWords")
        val muteWords: List<String>? = null    )

    @Serializable
    data class PlaceStreamServerCreateWebhookOutput(
        @SerialName("webhook")
        val webhook: PlaceStreamServerDefsWebhook    )

sealed class PlaceStreamServerCreateWebhookError(val name: String, val description: String?) {
        object InvalidUrl: PlaceStreamServerCreateWebhookError("InvalidUrl", "The provided webhook URL is invalid or unreachable.")
        object DuplicateWebhook: PlaceStreamServerCreateWebhookError("DuplicateWebhook", "A webhook with this URL already exists for this user.")
        object TooManyWebhooks: PlaceStreamServerCreateWebhookError("TooManyWebhooks", "The user has reached their maximum number of webhooks.")
    }

/**
 * Create a new webhook for receiving Streamplace events.
 *
 * Endpoint: place.stream.server.createWebhook
 */
suspend fun ATProtoClient.Place.Stream.Server.createWebhook(
input: PlaceStreamServerCreateWebhookInput): ATProtoResponse<PlaceStreamServerCreateWebhookOutput> {
    val endpoint = "place.stream.server.createWebhook"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
