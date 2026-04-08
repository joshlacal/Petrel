// Lexicon: 1, ID: blue.catbird.mlsChat.leaveConvo
// Leave an MLS conversation
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatLeaveConvoDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.leaveConvo"
}

@Serializable
    data class BlueCatbirdMlsChatLeaveConvoInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// DID of member to remove (defaults to caller's DID)        @SerialName("targetDid")
        val targetDid: DID? = null,// Optional base64url-encoded MLS Commit message        @SerialName("commit")
        val commit: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatLeaveConvoOutput(
// Whether the operation succeeded        @SerialName("success")
        val success: Boolean,// New epoch number after member removal        @SerialName("newEpoch")
        val newEpoch: Int    )

sealed class BlueCatbirdMlsChatLeaveConvoError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatLeaveConvoError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatLeaveConvoError("NotMember", "Caller is not a member of the conversation")
        object LastMember: BlueCatbirdMlsChatLeaveConvoError("LastMember", "Cannot leave as the last member (delete the conversation instead)")
    }

/**
 * Leave an MLS conversation
 *
 * Endpoint: blue.catbird.mlsChat.leaveConvo
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.leaveConvo(
input: BlueCatbirdMlsChatLeaveConvoInput): ATProtoResponse<BlueCatbirdMlsChatLeaveConvoOutput> {
    val endpoint = "blue.catbird.mlsChat.leaveConvo"

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
