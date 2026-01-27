// Lexicon: 1, ID: blue.catbird.mls.confirmWelcome
// Confirm successful or failed processing of Welcome message
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsConfirmWelcomeDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.confirmWelcome"
}

@Serializable
    data class BlueCatbirdMlsConfirmWelcomeInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Whether the Welcome message was successfully processed        @SerialName("success")
        val success: Boolean,// Optional error details if processing failed        @SerialName("errorDetails")
        val errorDetails: String? = null    )

    @Serializable
    data class BlueCatbirdMlsConfirmWelcomeOutput(
// Whether the confirmation was accepted        @SerialName("confirmed")
        val confirmed: Boolean    )

sealed class BlueCatbirdMlsConfirmWelcomeError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsConfirmWelcomeError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsConfirmWelcomeError("NotMember", "Caller is not a member of the conversation")
    }

/**
 * Confirm successful or failed processing of Welcome message
 *
 * Endpoint: blue.catbird.mls.confirmWelcome
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.confirmWelcome(
input: BlueCatbirdMlsConfirmWelcomeInput): ATProtoResponse<BlueCatbirdMlsConfirmWelcomeOutput> {
    val endpoint = "blue.catbird.mls.confirmWelcome"

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
