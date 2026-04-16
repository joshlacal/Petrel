// Lexicon: 1, ID: blue.catbird.mlsChat.checkBlocks
// Check whether any Bluesky block relationships exist between the given DIDs. Used by clients before creating a group or adding a member to warn the user that a block edge would force auto-leave.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatCheckBlocksDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.checkBlocks"
}

    @Serializable
    data class BlueCatbirdMlsChatCheckBlocksBlockRelationship(
        @SerialName("blockerDid")
        val blockerDid: DID,        @SerialName("blockedDid")
        val blockedDid: DID,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("blockUri")
        val blockUri: ATProtocolURI? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatCheckBlocksBlockRelationship"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatCheckBlocksInput(
// DIDs to check for mutual blocks (2–100 users).        @SerialName("dids")
        val dids: List<DID>    )

    @Serializable
    data class BlueCatbirdMlsChatCheckBlocksOutput(
// True if any block edge exists between any pair in the input.        @SerialName("blocked")
        val blocked: Boolean,// Every block edge found among the input DIDs.        @SerialName("blocks")
        val blocks: List<BlueCatbirdMlsChatCheckBlocksBlockRelationship>,        @SerialName("checkedAt")
        val checkedAt: ATProtocolDate    )

sealed class BlueCatbirdMlsChatCheckBlocksError(val name: String, val description: String?) {
        object TooFewDids: BlueCatbirdMlsChatCheckBlocksError("TooFewDids", "At least two DIDs are required.")
        object TooManyDids: BlueCatbirdMlsChatCheckBlocksError("TooManyDids", "Maximum 100 DIDs per request.")
        object BlueskyServiceUnavailable: BlueCatbirdMlsChatCheckBlocksError("BlueskyServiceUnavailable", "Upstream PDS query failed and local cache is empty.")
    }

/**
 * Check whether any Bluesky block relationships exist between the given DIDs. Used by clients before creating a group or adding a member to warn the user that a block edge would force auto-leave.
 *
 * Endpoint: blue.catbird.mlsChat.checkBlocks
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.checkBlocks(
input: BlueCatbirdMlsChatCheckBlocksInput): ATProtoResponse<BlueCatbirdMlsChatCheckBlocksOutput> {
    val endpoint = "blue.catbird.mlsChat.checkBlocks"

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
