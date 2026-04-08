// Lexicon: 1, ID: blue.catbird.mlsChat.getGroupState
// Get the current MLS group state for a conversation, including epoch and group info
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetGroupStateDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getGroupState"
}

@Serializable
    data class BlueCatbirdMlsChatGetGroupStateParameters(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Comma-separated list of fields to include in response        @SerialName("include")
        val include: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatGetGroupStateOutput(
// Current MLS epoch number        @SerialName("epoch")
        val epoch: Int? = null,// MLS group info bytes for external commit joins        @SerialName("groupInfo")
        val groupInfo: ByteArray? = null,// MLS welcome message bytes if available        @SerialName("welcome")
        val welcome: ByteArray? = null,// When the cached group info expires        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate? = null    )

sealed class BlueCatbirdMlsChatGetGroupStateError(val name: String, val description: String?) {
        object NotFound: BlueCatbirdMlsChatGetGroupStateError("NotFound", "Conversation not found")
        object Unauthorized: BlueCatbirdMlsChatGetGroupStateError("Unauthorized", "Authentication required")
        object GroupInfoUnavailable: BlueCatbirdMlsChatGetGroupStateError("GroupInfoUnavailable", "Group info is not currently available for this conversation")
    }

/**
 * Get the current MLS group state for a conversation, including epoch and group info
 *
 * Endpoint: blue.catbird.mlsChat.getGroupState
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getGroupState(
parameters: BlueCatbirdMlsChatGetGroupStateParameters): ATProtoResponse<BlueCatbirdMlsChatGetGroupStateOutput> {
    val endpoint = "blue.catbird.mlsChat.getGroupState"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
