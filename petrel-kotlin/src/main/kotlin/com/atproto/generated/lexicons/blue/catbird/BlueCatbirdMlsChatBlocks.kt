// Lexicon: 1, ID: blue.catbird.mlsChat.blocks
// Manage block relationships for MLS conversations. Supports checking block status, querying blocks between DIDs, and handling block changes.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatBlocksDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.blocks"
}

    /**
     * A block record change to process
     */
    @Serializable
    data class BlueCatbirdMlsChatBlocksBlockRecord(
/** DID of the user who created/deleted the block */        @SerialName("blockerDid")
        val blockerDid: DID,/** DID of the user being blocked/unblocked */        @SerialName("blockedDid")
        val blockedDid: DID,/** Whether the block was created or deleted */        @SerialName("action")
        val action: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatBlocksBlockRecord"
        }
    }

    /**
     * A block relationship between two users
     */
    @Serializable
    data class BlueCatbirdMlsChatBlocksBlockRelationship(
/** DID of the blocking user */        @SerialName("blockerDid")
        val blockerDid: DID,/** DID of the blocked user */        @SerialName("blockedDid")
        val blockedDid: DID,/** When the block was created */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** AT URI of the block record */        @SerialName("blockUri")
        val blockUri: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatBlocksBlockRelationship"
        }
    }

    /**
     * Block status for a specific conversation
     */
    @Serializable
    data class BlueCatbirdMlsChatBlocksConversationBlockStatus(
/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** Whether there are block conflicts in this conversation */        @SerialName("hasConflicts")
        val hasConflicts: Boolean,/** Number of members in the conversation */        @SerialName("memberCount")
        val memberCount: Int,/** When the status was last checked */        @SerialName("checkedAt")
        val checkedAt: ATProtocolDate?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatBlocksConversationBlockStatus"
        }
    }

    /**
     * Result of processing a block change for a conversation
     */
    @Serializable
    data class BlueCatbirdMlsChatBlocksBlockChangeResult(
/** Affected conversation identifier */        @SerialName("convoId")
        val convoId: String,/** Action taken */        @SerialName("action")
        val action: String,/** DID of the member removed due to block conflict */        @SerialName("removedDid")
        val removedDid: DID?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatBlocksBlockChangeResult"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatBlocksInput(
// Block action to perform        @SerialName("action")
        val action: String,// Conversation identifier (for getStatus action)        @SerialName("convoId")
        val convoId: String? = null,// DIDs to check for block relationships (for check action, 2-100 DIDs)        @SerialName("dids")
        val dids: List<String>? = null,// Block record for handleChange action        @SerialName("blockRecord")
        val blockRecord: BlueCatbirdMlsChatBlocksBlockRecord? = null    )

    @Serializable
    data class BlueCatbirdMlsChatBlocksOutput(
// Whether any block conflicts were found        @SerialName("hasConflicts")
        val hasConflicts: Boolean? = null,// Block relationships found        @SerialName("blocks")
        val blocks: List<BlueCatbirdMlsChatBlocksBlockRelationship>? = null,// When the check was performed        @SerialName("checkedAt")
        val checkedAt: ATProtocolDate? = null,// Block status for a specific conversation        @SerialName("status")
        val status: BlueCatbirdMlsChatBlocksConversationBlockStatus? = null,// Results of block change processing        @SerialName("changes")
        val changes: List<BlueCatbirdMlsChatBlocksBlockChangeResult>? = null    )

sealed class BlueCatbirdMlsChatBlocksError(val name: String, val description: String?) {
        object InvalidRequest: BlueCatbirdMlsChatBlocksError("InvalidRequest", "Invalid request parameters")
        object Unauthorized: BlueCatbirdMlsChatBlocksError("Unauthorized", "Authentication required")
    }

/**
 * Manage block relationships for MLS conversations. Supports checking block status, querying blocks between DIDs, and handling block changes.
 *
 * Endpoint: blue.catbird.mlsChat.blocks
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.blocks(
input: BlueCatbirdMlsChatBlocksInput): ATProtoResponse<BlueCatbirdMlsChatBlocksOutput> {
    val endpoint = "blue.catbird.mlsChat.blocks"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
