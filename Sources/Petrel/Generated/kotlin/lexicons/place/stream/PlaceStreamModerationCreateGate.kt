// Lexicon: 1, ID: place.stream.moderation.createGate
// Create a gate (hide message) on behalf of a streamer. Requires 'hide' permission. Creates a place.stream.chat.gate record in the streamer's repository.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamModerationCreateGateDefs {
    const val TYPE_IDENTIFIER = "place.stream.moderation.createGate"
}

@Serializable
    data class PlaceStreamModerationCreateGateInput(
// The DID of the streamer.        @SerialName("streamer")
        val streamer: DID,// The AT-URI of the chat message to hide.        @SerialName("messageUri")
        val messageUri: ATProtocolURI    )

    @Serializable
    data class PlaceStreamModerationCreateGateOutput(
// The AT-URI of the created gate record.        @SerialName("uri")
        val uri: ATProtocolURI,// The CID of the created gate record.        @SerialName("cid")
        val cid: CID    )

sealed class PlaceStreamModerationCreateGateError(val name: String, val description: String?) {
        object Unauthorized: PlaceStreamModerationCreateGateError("Unauthorized", "The request lacks valid authentication credentials.")
        object Forbidden: PlaceStreamModerationCreateGateError("Forbidden", "The caller does not have permission to hide messages for this streamer.")
        object SessionNotFound: PlaceStreamModerationCreateGateError("SessionNotFound", "The streamer's OAuth session could not be found or is invalid.")
    }

/**
 * Create a gate (hide message) on behalf of a streamer. Requires 'hide' permission. Creates a place.stream.chat.gate record in the streamer's repository.
 *
 * Endpoint: place.stream.moderation.createGate
 */
suspend fun ATProtoClient.Place.Stream.Moderation.createGate(
input: PlaceStreamModerationCreateGateInput): ATProtoResponse<PlaceStreamModerationCreateGateOutput> {
    val endpoint = "place.stream.moderation.createGate"

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
