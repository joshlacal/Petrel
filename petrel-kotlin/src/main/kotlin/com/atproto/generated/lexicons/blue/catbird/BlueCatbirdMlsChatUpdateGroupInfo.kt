// Lexicon: 1, ID: blue.catbird.mlsChat.updateGroupInfo
// Update the cached GroupInfo for a conversation. Should be called by clients after committing a group state change.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatUpdateGroupInfoDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.updateGroupInfo"
}

@Serializable
    data class BlueCatbirdMlsChatUpdateGroupInfoInput(
// The conversation ID        @SerialName("convoId")
        val convoId: String,// Base64 encoded serialized GroupInfo bytes        @SerialName("groupInfo")
        val groupInfo: String,// The epoch this GroupInfo corresponds to        @SerialName("epoch")
        val epoch: Int    )

    @Serializable
    data class BlueCatbirdMlsChatUpdateGroupInfoOutput(
        @SerialName("updated")
        val updated: Boolean    )

sealed class BlueCatbirdMlsChatUpdateGroupInfoError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsChatUpdateGroupInfoError("Unauthorized", "")
        object InvalidGroupInfo: BlueCatbirdMlsChatUpdateGroupInfoError("InvalidGroupInfo", "")
    }

/**
 * Update the cached GroupInfo for a conversation. Should be called by clients after committing a group state change.
 *
 * Endpoint: blue.catbird.mlsChat.updateGroupInfo
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.updateGroupInfo(
input: BlueCatbirdMlsChatUpdateGroupInfoInput): ATProtoResponse<BlueCatbirdMlsChatUpdateGroupInfoOutput> {
    val endpoint = "blue.catbird.mlsChat.updateGroupInfo"

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
