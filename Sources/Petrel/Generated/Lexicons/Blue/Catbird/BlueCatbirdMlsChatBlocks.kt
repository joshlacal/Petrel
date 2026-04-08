// Lexicon: 1, ID: blue.catbird.mlsChat.blocks
// Manage Bluesky block relationships for MLS conversations (consolidates checkBlocks + getBlockStatus + handleBlockChange) Check, query, or handle Bluesky block relationships relevant to MLS conversations. The 'action' field determines the operation.
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

    @Serializable
    data class BlueCatbirdMlsChatBlocksBlockRelationship(
/** DID of user who created the block */        @SerialName("blockerDid")
        val blockerDid: DID,/** DID of user who was blocked */        @SerialName("blockedDid")
        val blockedDid: DID,/** When the block was created */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** AT-URI of the block record on Bluesky */        @SerialName("blockUri")
        val blockUri: ATProtocolURI? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatBlocksBlockRelationship"
        }
    }

    @Serializable
    data class BlueCatbirdMlsChatBlocksBlockChangeRecord(
/** Whether a block was created or deleted */        @SerialName("action")
        val action: String,/** DID of the blocker */        @SerialName("blockerDid")
        val blockerDid: DID,/** DID of the blocked user */        @SerialName("blockedDid")
        val blockedDid: DID,/** AT-URI of the block record */        @SerialName("blockUri")
        val blockUri: ATProtocolURI? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatBlocksBlockChangeRecord"
        }
    }

    @Serializable
    data class BlueCatbirdMlsChatBlocksBlockChangeResult(
/** Affected conversation */        @SerialName("convoId")
        val convoId: String,/** Action taken in response to block change */        @SerialName("action")
        val action: String,/** DID of member removed (if action is memberRemoved) */        @SerialName("removedDid")
        val removedDid: DID? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatBlocksBlockChangeResult"
        }
    }

    @Serializable
    data class BlueCatbirdMlsChatBlocksConversationBlockStatus(
        @SerialName("convoId")
        val convoId: String,        @SerialName("hasConflicts")
        val hasConflicts: Boolean,        @SerialName("memberCount")
        val memberCount: Int,        @SerialName("checkedAt")
        val checkedAt: ATProtocolDate? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatBlocksConversationBlockStatus"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatBlocksInput(
// Block operation: 'check' queries Bluesky for block relationships between DIDs, 'getStatus' returns blocks within a conversation, 'handleChange' processes a block/unblock event from Bluesky firehose        @SerialName("action")
        val action: String,// DIDs to check for mutual blocks (required for 'check', 2-100 users)        @SerialName("dids")
        val dids: List<DID>? = null,// Conversation identifier (required for 'getStatus')        @SerialName("convoId")
        val convoId: String? = null,// DID involved in the block change (for 'handleChange')        @SerialName("did")
        val did: DID? = null,// Block/unblock event data from Bluesky firehose (for 'handleChange')        @SerialName("blockRecord")
        val blockRecord: BlueCatbirdMlsChatBlocksBlockChangeRecord? = null    )

    @Serializable
    data class BlueCatbirdMlsChatBlocksOutput(
// Whether any blocks exist (for 'check')        @SerialName("blocked")
        val blocked: Boolean? = null,// Block relationships found (for 'check' and 'getStatus')        @SerialName("blocks")
        val blocks: List<BlueCatbirdMlsChatBlocksBlockRelationship>? = null,// Whether any conversation members have blocked each other (for 'getStatus')        @SerialName("hasConflicts")
        val hasConflicts: Boolean? = null,// When the block status was checked        @SerialName("checkedAt")
        val checkedAt: ATProtocolDate? = null,// Results of handling block changes (for 'handleChange')        @SerialName("changes")
        val changes: List<BlueCatbirdMlsChatBlocksBlockChangeResult>? = null,// Full conversation block status (for 'getStatus')        @SerialName("status")
        val status: BlueCatbirdMlsChatBlocksConversationBlockStatus? = null    )

sealed class BlueCatbirdMlsChatBlocksError(val name: String, val description: String?) {
        object InvalidAction: BlueCatbirdMlsChatBlocksError("InvalidAction", "Unknown action value")
        object MissingDids: BlueCatbirdMlsChatBlocksError("MissingDids", "dids is required for 'check'")
        object TooManyDids: BlueCatbirdMlsChatBlocksError("TooManyDids", "Too many DIDs provided (max 100)")
        object ConvoNotFound: BlueCatbirdMlsChatBlocksError("ConvoNotFound", "Conversation not found (for 'getStatus')")
        object NotMember: BlueCatbirdMlsChatBlocksError("NotMember", "Caller is not a member (for 'getStatus')")
        object NotAdmin: BlueCatbirdMlsChatBlocksError("NotAdmin", "Admin privileges required (for 'getStatus')")
        object BlueskyServiceUnavailable: BlueCatbirdMlsChatBlocksError("BlueskyServiceUnavailable", "Could not reach Bluesky service")
    }

/**
 * Manage Bluesky block relationships for MLS conversations (consolidates checkBlocks + getBlockStatus + handleBlockChange) Check, query, or handle Bluesky block relationships relevant to MLS conversations. The 'action' field determines the operation.
 *
 * Endpoint: blue.catbird.mlsChat.blocks
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.blocks(
input: BlueCatbirdMlsChatBlocksInput): ATProtoResponse<BlueCatbirdMlsChatBlocksOutput> {
    val endpoint = "blue.catbird.mlsChat.blocks"

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
