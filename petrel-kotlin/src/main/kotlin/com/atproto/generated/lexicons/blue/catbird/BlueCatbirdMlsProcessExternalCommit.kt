// Lexicon: 1, ID: blue.catbird.mls.processExternalCommit
// Process an external commit for a conversation. This allows a client to add itself to a group using a cached GroupInfo.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsProcessExternalCommitDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.processExternalCommit"
}

@Serializable
    data class BlueCatbirdMlsProcessExternalCommitInput(
// The conversation ID        @SerialName("convoId")
        val convoId: String,// Base64 encoded serialized MLS Commit message        @SerialName("externalCommit")
        val externalCommit: String,// Optional idempotency key to prevent duplicate commits        @SerialName("idempotencyKey")
        val idempotencyKey: String? = null,// Optional Base64 encoded serialized GroupInfo. If provided, the server will atomically update the cached GroupInfo for the conversation.        @SerialName("groupInfo")
        val groupInfo: String? = null    )

    @Serializable
    data class BlueCatbirdMlsProcessExternalCommitOutput(
// The new epoch number after the commit (may be absent on older servers)        @SerialName("epoch")
        val epoch: Int? = null,// Timestamp of the rejoin        @SerialName("rejoinedAt")
        val rejoinedAt: ATProtocolDate? = null    )

sealed class BlueCatbirdMlsProcessExternalCommitError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsProcessExternalCommitError("Unauthorized", "")
        object InvalidCommit: BlueCatbirdMlsProcessExternalCommitError("InvalidCommit", "")
        object InvalidGroupInfo: BlueCatbirdMlsProcessExternalCommitError("InvalidGroupInfo", "")
    }

/**
 * Process an external commit for a conversation. This allows a client to add itself to a group using a cached GroupInfo.
 *
 * Endpoint: blue.catbird.mls.processExternalCommit
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.processExternalCommit(
input: BlueCatbirdMlsProcessExternalCommitInput): ATProtoResponse<BlueCatbirdMlsProcessExternalCommitOutput> {
    val endpoint = "blue.catbird.mls.processExternalCommit"

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
