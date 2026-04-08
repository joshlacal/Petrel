// Lexicon: 1, ID: blue.catbird.mlsChat.resetGroup
// Reset an MLS group by replacing its group ID and clearing ephemeral state Reset an MLS group for a conversation. Only admins may reset a group. This increments the reset count, swaps the group ID, resets the epoch to 0, and clears welcome messages and pending device additions.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatResetGroupDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.resetGroup"
}

@Serializable
    data class BlueCatbirdMlsChatResetGroupInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// New MLS group identifier to replace the current one        @SerialName("newGroupId")
        val newGroupId: String,// MLS cipher suite identifier for the new group        @SerialName("cipherSuite")
        val cipherSuite: String,// Optional base64-encoded MLS GroupInfo for the new group        @SerialName("groupInfo")
        val groupInfo: String? = null,// Optional human-readable reason for the reset        @SerialName("reason")
        val reason: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatResetGroupOutput(
// Whether the reset succeeded        @SerialName("success")
        val success: Boolean,// The new group identifier that was applied        @SerialName("newGroupId")
        val newGroupId: String,// Cumulative reset count for this conversation        @SerialName("resetGeneration")
        val resetGeneration: Int,// New epoch number (always 0 after reset)        @SerialName("newEpoch")
        val newEpoch: Int    )

sealed class BlueCatbirdMlsChatResetGroupError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatResetGroupError("ConvoNotFound", "Conversation not found")
        object NotAdmin: BlueCatbirdMlsChatResetGroupError("NotAdmin", "Caller is not an admin of the conversation")
        object GroupIdAlreadyExists: BlueCatbirdMlsChatResetGroupError("GroupIdAlreadyExists", "The new group ID is already in use by another conversation")
    }

/**
 * Reset an MLS group by replacing its group ID and clearing ephemeral state Reset an MLS group for a conversation. Only admins may reset a group. This increments the reset count, swaps the group ID, resets the epoch to 0, and clears welcome messages and pending device additions.
 *
 * Endpoint: blue.catbird.mlsChat.resetGroup
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.resetGroup(
input: BlueCatbirdMlsChatResetGroupInput): ATProtoResponse<BlueCatbirdMlsChatResetGroupOutput> {
    val endpoint = "blue.catbird.mlsChat.resetGroup"

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
