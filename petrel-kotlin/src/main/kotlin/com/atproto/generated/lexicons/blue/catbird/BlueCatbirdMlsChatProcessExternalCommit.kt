// Lexicon: 1, ID: blue.catbird.mlsChat.processExternalCommit
// Process an external commit for a conversation. This allows a client to add itself to a group using a cached GroupInfo.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatProcessExternalCommitDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.processExternalCommit"
}

@Serializable
    data class BlueCatbirdMlsChatProcessExternalCommitInput(
// The conversation ID        @SerialName("convoId")
        val convoId: String,// Base64 encoded serialized MLS Commit message        @SerialName("externalCommit")
        val externalCommit: String,// Optional idempotency key to prevent duplicate commits        @SerialName("idempotencyKey")
        val idempotencyKey: String? = null,// Optional Base64 encoded serialized GroupInfo. If provided, the server will atomically update the cached GroupInfo for the conversation.        @SerialName("groupInfo")
        val groupInfo: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatProcessExternalCommitOutput(
// The new epoch number after the commit (may be absent on older servers)        @SerialName("epoch")
        val epoch: Int? = null,// Timestamp of the rejoin        @SerialName("rejoinedAt")
        val rejoinedAt: ATProtocolDate? = null    )

sealed class BlueCatbirdMlsChatProcessExternalCommitError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsChatProcessExternalCommitError("Unauthorized", "")
        object InvalidCommit: BlueCatbirdMlsChatProcessExternalCommitError("InvalidCommit", "")
        object InvalidGroupInfo: BlueCatbirdMlsChatProcessExternalCommitError("InvalidGroupInfo", "")
    }

/**
 * Process an external commit for a conversation. This allows a client to add itself to a group using a cached GroupInfo.
 *
 * Endpoint: blue.catbird.mlsChat.processExternalCommit
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.processExternalCommit(
input: BlueCatbirdMlsChatProcessExternalCommitInput): ATProtoResponse<BlueCatbirdMlsChatProcessExternalCommitOutput> {
    val endpoint = "blue.catbird.mlsChat.processExternalCommit"

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
