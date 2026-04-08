// Lexicon: 1, ID: blue.catbird.mlsChat.getPolicy
// Retrieve conversation policy settings Query to fetch policy settings for a conversation. All members can view policy.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetPolicyDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getPolicy"
}

@Serializable
    data class BlueCatbirdMlsChatGetPolicyParameters(
// Conversation identifier        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class BlueCatbirdMlsChatGetPolicyOutput(
// Policy settings for this conversation        @SerialName("policy")
        val policy: BlueCatbirdMlsChatUpdatePolicyPolicyView    )

sealed class BlueCatbirdMlsChatGetPolicyError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatGetPolicyError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatGetPolicyError("NotMember", "Caller is not a member of this conversation")
    }

/**
 * Retrieve conversation policy settings Query to fetch policy settings for a conversation. All members can view policy.
 *
 * Endpoint: blue.catbird.mlsChat.getPolicy
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getPolicy(
parameters: BlueCatbirdMlsChatGetPolicyParameters): ATProtoResponse<BlueCatbirdMlsChatGetPolicyOutput> {
    val endpoint = "blue.catbird.mlsChat.getPolicy"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
