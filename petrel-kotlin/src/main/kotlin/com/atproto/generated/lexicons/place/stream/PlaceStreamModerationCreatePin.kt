// Lexicon: 1, ID: place.stream.moderation.createPin
// Pin a chat message on behalf of a streamer. Requires 'message.pin' permission. Creates a place.stream.chat.pinnedRecord in the streamer's repo, replacing any existing pin.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamModerationCreatePinDefs {
    const val TYPE_IDENTIFIER = "place.stream.moderation.createPin"
}

@Serializable
    data class PlaceStreamModerationCreatePinInput(
// The DID of the streamer.        @SerialName("streamer")
        val streamer: DID,// The AT-URI of the chat message to pin.        @SerialName("messageUri")
        val messageUri: ATProtocolURI,// Optional expiration time for this pin.        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate? = null    )

    @Serializable
    data class PlaceStreamModerationCreatePinOutput(
// The AT-URI of the created pinned record.        @SerialName("uri")
        val uri: ATProtocolURI,// The CID of the created pinned record.        @SerialName("cid")
        val cid: CID    )

sealed class PlaceStreamModerationCreatePinError(val name: String, val description: String?) {
        object Unauthorized: PlaceStreamModerationCreatePinError("Unauthorized", "The request lacks valid authentication credentials.")
        object Forbidden: PlaceStreamModerationCreatePinError("Forbidden", "The caller does not have permission to pin messages for this streamer.")
        object SessionNotFound: PlaceStreamModerationCreatePinError("SessionNotFound", "The streamer's OAuth session could not be found or is invalid.")
    }

/**
 * Pin a chat message on behalf of a streamer. Requires 'message.pin' permission. Creates a place.stream.chat.pinnedRecord in the streamer's repo, replacing any existing pin.
 *
 * Endpoint: place.stream.moderation.createPin
 */
suspend fun ATProtoClient.Place.Stream.Moderation.createPin(
input: PlaceStreamModerationCreatePinInput): ATProtoResponse<PlaceStreamModerationCreatePinOutput> {
    val endpoint = "place.stream.moderation.createPin"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
