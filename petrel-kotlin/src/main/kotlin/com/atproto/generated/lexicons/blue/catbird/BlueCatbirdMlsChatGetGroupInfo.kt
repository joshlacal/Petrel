// Lexicon: 1, ID: blue.catbird.mlsChat.getGroupInfo
// Fetch GroupInfo for external commit. Only available to current/past members.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetGroupInfoDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getGroupInfo"
}

@Serializable
    data class BlueCatbirdMlsChatGetGroupInfoParameters(
// Conversation ID        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class BlueCatbirdMlsChatGetGroupInfoOutput(
// Base64-encoded TLS-serialized GroupInfo        @SerialName("groupInfo")
        val groupInfo: String,// Current epoch number        @SerialName("epoch")
        val epoch: Int,// When GroupInfo becomes stale (5 minutes)        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate? = null    )

sealed class BlueCatbirdMlsChatGetGroupInfoError(val name: String, val description: String?) {
        object NotFound: BlueCatbirdMlsChatGetGroupInfoError("NotFound", "Conversation not found")
        object Unauthorized: BlueCatbirdMlsChatGetGroupInfoError("Unauthorized", "Not a current or past member")
        object GroupInfoUnavailable: BlueCatbirdMlsChatGetGroupInfoError("GroupInfoUnavailable", "GroupInfo not yet generated for this conversation")
    }

/**
 * Fetch GroupInfo for external commit. Only available to current/past members.
 *
 * Endpoint: blue.catbird.mlsChat.getGroupInfo
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getGroupInfo(
parameters: BlueCatbirdMlsChatGetGroupInfoParameters): ATProtoResponse<BlueCatbirdMlsChatGetGroupInfoOutput> {
    val endpoint = "blue.catbird.mlsChat.getGroupInfo"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
