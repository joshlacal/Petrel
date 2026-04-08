// Lexicon: 1, ID: place.stream.moderation.deletePin
// Unpin a pinned chat message on behalf of a streamer. Requires 'message.pin' permission. Deletes the place.stream.chat.pinnedRecord from the streamer's repo.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamModerationDeletePinDefs {
    const val TYPE_IDENTIFIER = "place.stream.moderation.deletePin"
}

@Serializable
    data class PlaceStreamModerationDeletePinInput(
// The DID of the streamer.        @SerialName("streamer")
        val streamer: DID,// The AT-URI of the pinned record to delete.        @SerialName("pinUri")
        val pinUri: ATProtocolURI    )

    @Serializable
    class PlaceStreamModerationDeletePinOutput

sealed class PlaceStreamModerationDeletePinError(val name: String, val description: String?) {
        object Unauthorized: PlaceStreamModerationDeletePinError("Unauthorized", "The request lacks valid authentication credentials.")
        object Forbidden: PlaceStreamModerationDeletePinError("Forbidden", "The caller does not have permission to unpin messages for this streamer.")
        object SessionNotFound: PlaceStreamModerationDeletePinError("SessionNotFound", "The streamer's OAuth session could not be found or is invalid.")
    }

/**
 * Unpin a pinned chat message on behalf of a streamer. Requires 'message.pin' permission. Deletes the place.stream.chat.pinnedRecord from the streamer's repo.
 *
 * Endpoint: place.stream.moderation.deletePin
 */
suspend fun ATProtoClient.Place.Stream.Moderation.deletePin(
input: PlaceStreamModerationDeletePinInput): ATProtoResponse<PlaceStreamModerationDeletePinOutput> {
    val endpoint = "place.stream.moderation.deletePin"

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
