// Lexicon: 1, ID: blue.catbird.mlsChat.getBlockStatus
// Get block relationships relevant to a specific conversation Query block status for all members of a conversation. Returns any block relationships between current members. Useful for admins to identify and resolve block conflicts.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetBlockStatusDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getBlockStatus"
}

@Serializable
    data class BlueCatbirdMlsChatGetBlockStatusParameters(
// Conversation identifier        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class BlueCatbirdMlsChatGetBlockStatusOutput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// True if any members have blocked each other        @SerialName("hasConflicts")
        val hasConflicts: Boolean,// List of block relationships between conversation members        @SerialName("blocks")
        val blocks: List<BlueCatbirdMlsChatCheckBlocksBlockRelationship>,// When the block status was checked        @SerialName("checkedAt")
        val checkedAt: ATProtocolDate,// Total number of members checked        @SerialName("memberCount")
        val memberCount: Int? = null    )

sealed class BlueCatbirdMlsChatGetBlockStatusError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatGetBlockStatusError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatGetBlockStatusError("NotMember", "Caller is not a member of this conversation")
        object NotAdmin: BlueCatbirdMlsChatGetBlockStatusError("NotAdmin", "Only admins can check block status")
    }

/**
 * Get block relationships relevant to a specific conversation Query block status for all members of a conversation. Returns any block relationships between current members. Useful for admins to identify and resolve block conflicts.
 *
 * Endpoint: blue.catbird.mlsChat.getBlockStatus
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getBlockStatus(
parameters: BlueCatbirdMlsChatGetBlockStatusParameters): ATProtoResponse<BlueCatbirdMlsChatGetBlockStatusOutput> {
    val endpoint = "blue.catbird.mlsChat.getBlockStatus"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
