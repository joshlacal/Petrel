// Lexicon: 1, ID: blue.catbird.mls.getExpectedConversations
// Get list of conversations the user should be a member of but may be missing locally Returns conversations where the user is a member on the server but may not have local MLS state
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetExpectedConversationsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getExpectedConversations"
}

    @Serializable
    data class BlueCatbirdMlsGetExpectedConversationsExpectedConversation(
/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** Conversation name */        @SerialName("name")
        val name: String,/** Number of active members in conversation */        @SerialName("memberCount")
        val memberCount: Int,/** Whether this device should be in the MLS group */        @SerialName("shouldBeInGroup")
        val shouldBeInGroup: Boolean,/** Timestamp of last activity in conversation */        @SerialName("lastActivity")
        val lastActivity: ATProtocolDate?,/** Whether user has an active rejoin request for this conversation */        @SerialName("needsRejoin")
        val needsRejoin: Boolean?,/** Whether the specific device is currently in the MLS group */        @SerialName("deviceInGroup")
        val deviceInGroup: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsGetExpectedConversationsExpectedConversation"
        }
    }

@Serializable
    data class BlueCatbirdMlsGetExpectedConversationsParameters(
// Optional device ID to check. Defaults to current device from auth token        @SerialName("deviceId")
        val deviceId: String? = null    )

    @Serializable
    data class BlueCatbirdMlsGetExpectedConversationsOutput(
// List of conversations the user should be in        @SerialName("conversations")
        val conversations: List<BlueCatbirdMlsGetExpectedConversationsExpectedConversation>    )

sealed class BlueCatbirdMlsGetExpectedConversationsError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsGetExpectedConversationsError("Unauthorized", "Authentication required")
    }

/**
 * Get list of conversations the user should be a member of but may be missing locally Returns conversations where the user is a member on the server but may not have local MLS state
 *
 * Endpoint: blue.catbird.mls.getExpectedConversations
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getExpectedConversations(
parameters: BlueCatbirdMlsGetExpectedConversationsParameters): ATProtoResponse<BlueCatbirdMlsGetExpectedConversationsOutput> {
    val endpoint = "blue.catbird.mls.getExpectedConversations"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
