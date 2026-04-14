// Lexicon: 1, ID: place.stream.moderation.createBlock
// Create a block (ban) on behalf of a streamer. Requires 'ban' permission. Creates an app.bsky.graph.block record in the streamer's repository.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamModerationCreateBlockDefs {
    const val TYPE_IDENTIFIER = "place.stream.moderation.createBlock"
}

@Serializable
    data class PlaceStreamModerationCreateBlockInput(
// The DID of the streamer whose chat this block applies to.        @SerialName("streamer")
        val streamer: DID,// The DID of the user being blocked from chat.        @SerialName("subject")
        val subject: DID,// Optional reason for the block.        @SerialName("reason")
        val reason: String? = null    )

    @Serializable
    data class PlaceStreamModerationCreateBlockOutput(
// The AT-URI of the created block record.        @SerialName("uri")
        val uri: ATProtocolURI,// The CID of the created block record.        @SerialName("cid")
        val cid: CID    )

sealed class PlaceStreamModerationCreateBlockError(val name: String, val description: String?) {
        object Unauthorized: PlaceStreamModerationCreateBlockError("Unauthorized", "The request lacks valid authentication credentials.")
        object Forbidden: PlaceStreamModerationCreateBlockError("Forbidden", "The caller does not have permission to create blocks for this streamer.")
        object SessionNotFound: PlaceStreamModerationCreateBlockError("SessionNotFound", "The streamer's OAuth session could not be found or is invalid.")
    }

/**
 * Create a block (ban) on behalf of a streamer. Requires 'ban' permission. Creates an app.bsky.graph.block record in the streamer's repository.
 *
 * Endpoint: place.stream.moderation.createBlock
 */
suspend fun ATProtoClient.Place.Stream.Moderation.createBlock(
input: PlaceStreamModerationCreateBlockInput): ATProtoResponse<PlaceStreamModerationCreateBlockOutput> {
    val endpoint = "place.stream.moderation.createBlock"

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
