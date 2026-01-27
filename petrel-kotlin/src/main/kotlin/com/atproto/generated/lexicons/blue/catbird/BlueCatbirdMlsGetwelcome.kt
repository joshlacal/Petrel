// Lexicon: 1, ID: blue.catbird.mls.getWelcome
// Get Welcome message for joining an MLS conversation Retrieve the Welcome message for a conversation the user is a member of
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetWelcomeDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getWelcome"
}

@Serializable
    data class BlueCatbirdMlsGetWelcomeParameters(
// Conversation identifier        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class BlueCatbirdMlsGetWelcomeOutput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Base64url-encoded MLS Welcome message data        @SerialName("welcome")
        val welcome: String    )

sealed class BlueCatbirdMlsGetWelcomeError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsGetWelcomeError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsGetWelcomeError("NotMember", "Caller is not a member of the conversation")
        object WelcomeNotFound: BlueCatbirdMlsGetWelcomeError("WelcomeNotFound", "No Welcome message available for this user")
    }

/**
 * Get Welcome message for joining an MLS conversation Retrieve the Welcome message for a conversation the user is a member of
 *
 * Endpoint: blue.catbird.mls.getWelcome
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getWelcome(
parameters: BlueCatbirdMlsGetWelcomeParameters): ATProtoResponse<BlueCatbirdMlsGetWelcomeOutput> {
    val endpoint = "blue.catbird.mls.getWelcome"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
