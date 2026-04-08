// Lexicon: 1, ID: blue.catbird.mls.getPolicy
// Retrieve conversation policy settings Query to fetch policy settings for a conversation. All members can view policy.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetPolicyDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getPolicy"
}

@Serializable
    data class BlueCatbirdMlsGetPolicyParameters(
// Conversation identifier        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class BlueCatbirdMlsGetPolicyOutput(
// Policy settings for this conversation        @SerialName("policy")
        val policy: BlueCatbirdMlsUpdatePolicyPolicyView    )

sealed class BlueCatbirdMlsGetPolicyError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsGetPolicyError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsGetPolicyError("NotMember", "Caller is not a member of this conversation")
    }

/**
 * Retrieve conversation policy settings Query to fetch policy settings for a conversation. All members can view policy.
 *
 * Endpoint: blue.catbird.mls.getPolicy
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getPolicy(
parameters: BlueCatbirdMlsGetPolicyParameters): ATProtoResponse<BlueCatbirdMlsGetPolicyOutput> {
    val endpoint = "blue.catbird.mls.getPolicy"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
