// Lexicon: 1, ID: blue.catbird.mls.getGroupInfo
// Fetch GroupInfo for external commit. Only available to current/past members.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetGroupInfoDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getGroupInfo"
}

@Serializable
    data class BlueCatbirdMlsGetGroupInfoParameters(
// Conversation ID        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class BlueCatbirdMlsGetGroupInfoOutput(
// Base64-encoded TLS-serialized GroupInfo        @SerialName("groupInfo")
        val groupInfo: String,// Current epoch number        @SerialName("epoch")
        val epoch: Int,// When GroupInfo becomes stale (5 minutes)        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate? = null    )

sealed class BlueCatbirdMlsGetGroupInfoError(val name: String, val description: String?) {
        object NotFound: BlueCatbirdMlsGetGroupInfoError("NotFound", "Conversation not found")
        object Unauthorized: BlueCatbirdMlsGetGroupInfoError("Unauthorized", "Not a current or past member")
        object GroupInfoUnavailable: BlueCatbirdMlsGetGroupInfoError("GroupInfoUnavailable", "GroupInfo not yet generated for this conversation")
    }

/**
 * Fetch GroupInfo for external commit. Only available to current/past members.
 *
 * Endpoint: blue.catbird.mls.getGroupInfo
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getGroupInfo(
parameters: BlueCatbirdMlsGetGroupInfoParameters): ATProtoResponse<BlueCatbirdMlsGetGroupInfoOutput> {
    val endpoint = "blue.catbird.mls.getGroupInfo"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
