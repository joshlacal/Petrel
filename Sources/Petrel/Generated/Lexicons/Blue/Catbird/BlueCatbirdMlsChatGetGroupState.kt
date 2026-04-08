// Lexicon: 1, ID: blue.catbird.mlsChat.getGroupState
// Retrieve group state including GroupInfo, epoch, and welcome data (consolidates getGroupInfo + getEpoch + validateWelcome) Fetch MLS group state for a conversation. The 'include' parameter selects which state components to return, reducing multiple round-trips to a single call.
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
        val convoId: String,// Comma-separated list of state components to include: 'groupInfo' (TLS-serialized GroupInfo for external commit), 'welcome' (pending Welcome message), 'epoch' (current epoch number). Defaults to 'groupInfo,epoch'.        @SerialName("include")
        val include: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatGetGroupStateOutput(
// TLS-serialized GroupInfo (present when 'groupInfo' included)        @SerialName("groupInfo")
        val groupInfo: Bytes? = null,// Current MLS epoch number (present when 'epoch' included)        @SerialName("epoch")
        val epoch: Int? = null,// Pending MLS Welcome message (present when 'welcome' included and a Welcome exists)        @SerialName("welcome")
        val welcome: Bytes? = null,// When the GroupInfo becomes stale (typically 5 minutes)        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate? = null    )

sealed class BlueCatbirdMlsChatGetGroupStateError(val name: String, val description: String?) {
        object NotFound: BlueCatbirdMlsChatGetGroupStateError("NotFound", "Conversation not found")
        object Unauthorized: BlueCatbirdMlsChatGetGroupStateError("Unauthorized", "Not a current or past member")
        object GroupInfoUnavailable: BlueCatbirdMlsChatGetGroupStateError("GroupInfoUnavailable", "GroupInfo not yet generated for this conversation")
    }

/**
 * Retrieve group state including GroupInfo, epoch, and welcome data (consolidates getGroupInfo + getEpoch + validateWelcome) Fetch MLS group state for a conversation. The 'include' parameter selects which state components to return, reducing multiple round-trips to a single call.
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
