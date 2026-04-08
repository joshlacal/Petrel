// Lexicon: 1, ID: blue.catbird.mlsChat.getEpoch
// Get the current epoch for an MLS conversation
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetEpochDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getEpoch"
}

@Serializable
    data class BlueCatbirdMlsChatGetEpochParameters(
// Conversation identifier        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class BlueCatbirdMlsChatGetEpochOutput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Current MLS epoch number        @SerialName("currentEpoch")
        val currentEpoch: Int    )

sealed class BlueCatbirdMlsChatGetEpochError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatGetEpochError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatGetEpochError("NotMember", "Caller is not a member of the conversation")
    }

/**
 * Get the current epoch for an MLS conversation
 *
 * Endpoint: blue.catbird.mlsChat.getEpoch
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getEpoch(
parameters: BlueCatbirdMlsChatGetEpochParameters): ATProtoResponse<BlueCatbirdMlsChatGetEpochOutput> {
    val endpoint = "blue.catbird.mlsChat.getEpoch"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
