// Lexicon: 1, ID: blue.catbird.mls.getEpoch
// Get the current epoch for an MLS conversation
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetEpochDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getEpoch"
}

@Serializable
    data class BlueCatbirdMlsGetEpochParameters(
// Conversation identifier        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class BlueCatbirdMlsGetEpochOutput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Current MLS epoch number        @SerialName("currentEpoch")
        val currentEpoch: Int    )

sealed class BlueCatbirdMlsGetEpochError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsGetEpochError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsGetEpochError("NotMember", "Caller is not a member of the conversation")
    }

/**
 * Get the current epoch for an MLS conversation
 *
 * Endpoint: blue.catbird.mls.getEpoch
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getEpoch(
parameters: BlueCatbirdMlsGetEpochParameters): ATProtoResponse<BlueCatbirdMlsGetEpochOutput> {
    val endpoint = "blue.catbird.mls.getEpoch"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
