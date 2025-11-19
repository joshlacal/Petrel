// Lexicon: 1, ID: com.atproto.server.createInviteCode
// Create an invite code.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerCreateinvitecode {
    const val TYPE_IDENTIFIER = "com.atproto.server.createInviteCode"

    @Serializable
    data class Input(
        @SerialName("useCount")
        val useCount: Int,        @SerialName("forAccount")
        val forAccount: DID? = null    )

        @Serializable
    data class Output(
        @SerialName("code")
        val code: String    )

}

/**
 * Create an invite code.
 *
 * Endpoint: com.atproto.server.createInviteCode
 */
suspend fun ATProtoClient.Com.Atproto.Server.createinvitecode(
input: ComAtprotoServerCreateinvitecode.Input): ATProtoResponse<ComAtprotoServerCreateinvitecode.Output> {
    val endpoint = "com.atproto.server.createInviteCode"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
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
