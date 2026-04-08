// Lexicon: 1, ID: blue.catbird.mlsChat.getExpectedConversations
// Get list of conversations the user should be a member of but may be missing locally Returns conversations where the user is a member on the server but may not have local MLS state
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetExpectedConversationsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getExpectedConversations"
}

    @Serializable
    data class BlueCatbirdMlsChatGetExpectedConversationsExpectedConversation(
/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** Conversation name */        @SerialName("name")
        val name: String,/** Number of active members in conversation */        @SerialName("memberCount")
        val memberCount: Int,/** Whether this device should be in the MLS group */        @SerialName("shouldBeInGroup")
        val shouldBeInGroup: Boolean,/** Timestamp of last activity in conversation */        @SerialName("lastActivity")
        val lastActivity: ATProtocolDate?,/** Whether user has an active rejoin request for this conversation */        @SerialName("needsRejoin")
        val needsRejoin: Boolean?,/** Whether the specific device is currently in the MLS group */        @SerialName("deviceInGroup")
        val deviceInGroup: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatGetExpectedConversationsExpectedConversation"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatGetExpectedConversationsParameters(
// Optional device ID to check. Defaults to current device from auth token        @SerialName("deviceId")
        val deviceId: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatGetExpectedConversationsOutput(
// List of conversations the user should be in        @SerialName("conversations")
        val conversations: List<BlueCatbirdMlsChatGetExpectedConversationsExpectedConversation>    )

sealed class BlueCatbirdMlsChatGetExpectedConversationsError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsChatGetExpectedConversationsError("Unauthorized", "Authentication required")
    }

/**
 * Get list of conversations the user should be a member of but may be missing locally Returns conversations where the user is a member on the server but may not have local MLS state
 *
 * Endpoint: blue.catbird.mlsChat.getExpectedConversations
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getExpectedConversations(
parameters: BlueCatbirdMlsChatGetExpectedConversationsParameters): ATProtoResponse<BlueCatbirdMlsChatGetExpectedConversationsOutput> {
    val endpoint = "blue.catbird.mlsChat.getExpectedConversations"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
