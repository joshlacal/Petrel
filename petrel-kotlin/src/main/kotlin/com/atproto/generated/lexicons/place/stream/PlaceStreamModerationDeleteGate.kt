// Lexicon: 1, ID: place.stream.moderation.deleteGate
// Delete a gate (unhide message) on behalf of a streamer. Requires 'hide' permission. Deletes a place.stream.chat.gate record from the streamer's repository.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamModerationDeleteGateDefs {
    const val TYPE_IDENTIFIER = "place.stream.moderation.deleteGate"
}

@Serializable
    data class PlaceStreamModerationDeleteGateInput(
// The DID of the streamer.        @SerialName("streamer")
        val streamer: DID,// The AT-URI of the gate record to delete.        @SerialName("gateUri")
        val gateUri: ATProtocolURI    )

    @Serializable
    class PlaceStreamModerationDeleteGateOutput

sealed class PlaceStreamModerationDeleteGateError(val name: String, val description: String?) {
        object Unauthorized: PlaceStreamModerationDeleteGateError("Unauthorized", "The request lacks valid authentication credentials.")
        object Forbidden: PlaceStreamModerationDeleteGateError("Forbidden", "The caller does not have permission to unhide messages for this streamer.")
        object SessionNotFound: PlaceStreamModerationDeleteGateError("SessionNotFound", "The streamer's OAuth session could not be found or is invalid.")
    }

/**
 * Delete a gate (unhide message) on behalf of a streamer. Requires 'hide' permission. Deletes a place.stream.chat.gate record from the streamer's repository.
 *
 * Endpoint: place.stream.moderation.deleteGate
 */
suspend fun ATProtoClient.Place.Stream.Moderation.deleteGate(
input: PlaceStreamModerationDeleteGateInput): ATProtoResponse<PlaceStreamModerationDeleteGateOutput> {
    val endpoint = "place.stream.moderation.deleteGate"

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
