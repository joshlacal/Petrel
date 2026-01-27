// Lexicon: 1, ID: blue.catbird.mls.leaveConvo
// Leave an MLS conversation
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsLeaveConvoDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.leaveConvo"
}

@Serializable
    data class BlueCatbirdMlsLeaveConvoInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// DID of member to remove (defaults to caller's DID)        @SerialName("targetDid")
        val targetDid: DID? = null,// Optional base64url-encoded MLS Commit message        @SerialName("commit")
        val commit: String? = null    )

    @Serializable
    data class BlueCatbirdMlsLeaveConvoOutput(
// Whether the operation succeeded        @SerialName("success")
        val success: Boolean,// New epoch number after member removal        @SerialName("newEpoch")
        val newEpoch: Int    )

sealed class BlueCatbirdMlsLeaveConvoError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsLeaveConvoError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsLeaveConvoError("NotMember", "Caller is not a member of the conversation")
        object LastMember: BlueCatbirdMlsLeaveConvoError("LastMember", "Cannot leave as the last member (delete the conversation instead)")
    }

/**
 * Leave an MLS conversation
 *
 * Endpoint: blue.catbird.mls.leaveConvo
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.leaveConvo(
input: BlueCatbirdMlsLeaveConvoInput): ATProtoResponse<BlueCatbirdMlsLeaveConvoOutput> {
    val endpoint = "blue.catbird.mls.leaveConvo"

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
