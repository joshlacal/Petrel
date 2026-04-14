// Lexicon: 1, ID: place.stream.moderation.deleteBlock
// Delete a block (unban) on behalf of a streamer. Requires 'ban' permission. Deletes an app.bsky.graph.block record from the streamer's repository.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamModerationDeleteBlockDefs {
    const val TYPE_IDENTIFIER = "place.stream.moderation.deleteBlock"
}

@Serializable
    data class PlaceStreamModerationDeleteBlockInput(
// The DID of the streamer.        @SerialName("streamer")
        val streamer: DID,// The AT-URI of the block record to delete.        @SerialName("blockUri")
        val blockUri: ATProtocolURI    )

    @Serializable
    class PlaceStreamModerationDeleteBlockOutput

sealed class PlaceStreamModerationDeleteBlockError(val name: String, val description: String?) {
        object Unauthorized: PlaceStreamModerationDeleteBlockError("Unauthorized", "The request lacks valid authentication credentials.")
        object Forbidden: PlaceStreamModerationDeleteBlockError("Forbidden", "The caller does not have permission to delete blocks for this streamer.")
        object SessionNotFound: PlaceStreamModerationDeleteBlockError("SessionNotFound", "The streamer's OAuth session could not be found or is invalid.")
    }

/**
 * Delete a block (unban) on behalf of a streamer. Requires 'ban' permission. Deletes an app.bsky.graph.block record from the streamer's repository.
 *
 * Endpoint: place.stream.moderation.deleteBlock
 */
suspend fun ATProtoClient.Place.Stream.Moderation.deleteBlock(
input: PlaceStreamModerationDeleteBlockInput): ATProtoResponse<PlaceStreamModerationDeleteBlockOutput> {
    val endpoint = "place.stream.moderation.deleteBlock"

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
