// Lexicon: 1, ID: place.stream.moderation.updateLivestream
// Update livestream metadata on behalf of a streamer. Requires 'livestream.manage' permission. Updates a place.stream.livestream record in the streamer's repository.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamModerationUpdateLivestreamDefs {
    const val TYPE_IDENTIFIER = "place.stream.moderation.updateLivestream"
}

@Serializable
    data class PlaceStreamModerationUpdateLivestreamInput(
// The DID of the streamer.        @SerialName("streamer")
        val streamer: DID,// The AT-URI of the livestream record to update.        @SerialName("livestreamUri")
        val livestreamUri: ATProtocolURI,// New title for the livestream.        @SerialName("title")
        val title: String? = null    )

    @Serializable
    data class PlaceStreamModerationUpdateLivestreamOutput(
// The AT-URI of the updated livestream record.        @SerialName("uri")
        val uri: ATProtocolURI,// The CID of the updated livestream record.        @SerialName("cid")
        val cid: CID    )

sealed class PlaceStreamModerationUpdateLivestreamError(val name: String, val description: String?) {
        object Unauthorized: PlaceStreamModerationUpdateLivestreamError("Unauthorized", "The request lacks valid authentication credentials.")
        object Forbidden: PlaceStreamModerationUpdateLivestreamError("Forbidden", "The caller does not have permission to update livestream metadata for this streamer.")
        object SessionNotFound: PlaceStreamModerationUpdateLivestreamError("SessionNotFound", "The streamer's OAuth session could not be found or is invalid.")
        object RecordNotFound: PlaceStreamModerationUpdateLivestreamError("RecordNotFound", "The specified livestream record does not exist.")
    }

/**
 * Update livestream metadata on behalf of a streamer. Requires 'livestream.manage' permission. Updates a place.stream.livestream record in the streamer's repository.
 *
 * Endpoint: place.stream.moderation.updateLivestream
 */
suspend fun ATProtoClient.Place.Stream.Moderation.updateLivestream(
input: PlaceStreamModerationUpdateLivestreamInput): ATProtoResponse<PlaceStreamModerationUpdateLivestreamOutput> {
    val endpoint = "place.stream.moderation.updateLivestream"

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
