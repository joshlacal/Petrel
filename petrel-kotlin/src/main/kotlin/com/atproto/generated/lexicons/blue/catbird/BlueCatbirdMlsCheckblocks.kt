// Lexicon: 1, ID: blue.catbird.mls.checkBlocks
// Check Bluesky block relationships between users for MLS conversation moderation Query Bluesky social graph to check block status between users. Returns block relationships relevant to MLS conversation membership. Server queries Bluesky PDS for current block state. Used before adding members to prevent blocked users from joining the same conversation.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsCheckBlocksDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.checkBlocks"
}

    /**
     * Represents a block relationship between two users on Bluesky
     */
    @Serializable
    data class BlueCatbirdMlsCheckBlocksBlockRelationship(
/** DID of user who created the block */        @SerialName("blockerDid")
        val blockerDid: DID,/** DID of user who was blocked */        @SerialName("blockedDid")
        val blockedDid: DID,/** When the block was created on Bluesky */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** AT-URI of the block record on Bluesky (for verification) */        @SerialName("blockUri")
        val blockUri: ATProtocolURI?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsCheckBlocksBlockRelationship"
        }
    }

@Serializable
    data class BlueCatbirdMlsCheckBlocksParameters(
// DIDs to check for mutual blocks (2-100 users)        @SerialName("dids")
        val dids: List<DID>    )

    @Serializable
    data class BlueCatbirdMlsCheckBlocksOutput(
// List of block relationships between the provided DIDs        @SerialName("blocks")
        val blocks: List<BlueCatbirdMlsCheckBlocksBlockRelationship>,// When the block status was checked (for cache invalidation)        @SerialName("checkedAt")
        val checkedAt: ATProtocolDate    )

sealed class BlueCatbirdMlsCheckBlocksError(val name: String, val description: String?) {
        object TooManyDids: BlueCatbirdMlsCheckBlocksError("TooManyDids", "Too many DIDs provided (max 100)")
        object BlueskyServiceUnavailable: BlueCatbirdMlsCheckBlocksError("BlueskyServiceUnavailable", "Could not reach Bluesky service to check blocks")
    }

/**
 * Check Bluesky block relationships between users for MLS conversation moderation Query Bluesky social graph to check block status between users. Returns block relationships relevant to MLS conversation membership. Server queries Bluesky PDS for current block state. Used before adding members to prevent blocked users from joining the same conversation.
 *
 * Endpoint: blue.catbird.mls.checkBlocks
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.checkBlocks(
parameters: BlueCatbirdMlsCheckBlocksParameters): ATProtoResponse<BlueCatbirdMlsCheckBlocksOutput> {
    val endpoint = "blue.catbird.mls.checkBlocks"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
