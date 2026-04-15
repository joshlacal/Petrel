// Lexicon: 1, ID: blue.catbird.mlsChat.getBlockStatus
// Return the current block-edge status for an MLS conversation (which pairs of members block each other). Diagnostic; not used for enforcement.
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
    data class BlueCatbirdMlsChatGetBlockStatusBlockRelationship(
        @SerialName("blockerDid")
        val blockerDid: DID,        @SerialName("blockedDid")
        val blockedDid: DID,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("blockUri")
        val blockUri: ATProtocolURI? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatGetBlockStatusBlockRelationship"
        }
    }

    @Serializable
    data class BlueCatbirdMlsChatGetBlockStatusConversationBlockStatus(
        @SerialName("convoId")
        val convoId: String,        @SerialName("hasConflicts")
        val hasConflicts: Boolean,        @SerialName("memberCount")
        val memberCount: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatGetBlockStatusConversationBlockStatus"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatGetBlockStatusInput(
        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class BlueCatbirdMlsChatGetBlockStatusOutput(
        @SerialName("status")
        val status: BlueCatbirdMlsChatGetBlockStatusConversationBlockStatus,        @SerialName("blocks")
        val blocks: List<BlueCatbirdMlsChatGetBlockStatusBlockRelationship>,        @SerialName("checkedAt")
        val checkedAt: ATProtocolDate    )

sealed class BlueCatbirdMlsChatGetBlockStatusError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatGetBlockStatusError("ConvoNotFound", "No conversation with the given ID.")
        object NotMember: BlueCatbirdMlsChatGetBlockStatusError("NotMember", "Caller is not a member of this conversation.")
    }

/**
 * Return the current block-edge status for an MLS conversation (which pairs of members block each other). Diagnostic; not used for enforcement.
 *
 * Endpoint: blue.catbird.mlsChat.getBlockStatus
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getBlockStatus(
input: BlueCatbirdMlsChatGetBlockStatusInput): ATProtoResponse<BlueCatbirdMlsChatGetBlockStatusOutput> {
    val endpoint = "blue.catbird.mlsChat.getBlockStatus"

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
