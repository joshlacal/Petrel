// Lexicon: 1, ID: place.stream.live.denyTeleport
// Deny an incoming teleport request.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamLiveDenyTeleportDefs {
    const val TYPE_IDENTIFIER = "place.stream.live.denyTeleport"
}

@Serializable
    data class PlaceStreamLiveDenyTeleportInput(
// The URI of the teleport record to deny.        @SerialName("uri")
        val uri: ATProtocolURI    )

    @Serializable
    data class PlaceStreamLiveDenyTeleportOutput(
// Whether the teleport was successfully denied.        @SerialName("success")
        val success: Boolean    )

sealed class PlaceStreamLiveDenyTeleportError(val name: String, val description: String?) {
        object TeleportNotFound: PlaceStreamLiveDenyTeleportError("TeleportNotFound", "The specified teleport was not found.")
        object Unauthorized: PlaceStreamLiveDenyTeleportError("Unauthorized", "The authenticated user is not the target of this teleport.")
    }

/**
 * Deny an incoming teleport request.
 *
 * Endpoint: place.stream.live.denyTeleport
 */
suspend fun ATProtoClient.Place.Stream.Live.denyTeleport(
input: PlaceStreamLiveDenyTeleportInput): ATProtoResponse<PlaceStreamLiveDenyTeleportOutput> {
    val endpoint = "place.stream.live.denyTeleport"

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
