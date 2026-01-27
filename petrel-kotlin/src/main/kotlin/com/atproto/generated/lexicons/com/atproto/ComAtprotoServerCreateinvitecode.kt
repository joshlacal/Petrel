// Lexicon: 1, ID: com.atproto.server.createInviteCode
// Create an invite code.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerCreateInviteCodeDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.createInviteCode"
}

@Serializable
    data class ComAtprotoServerCreateInviteCodeInput(
        @SerialName("useCount")
        val useCount: Int,        @SerialName("forAccount")
        val forAccount: DID? = null    )

    @Serializable
    data class ComAtprotoServerCreateInviteCodeOutput(
        @SerialName("code")
        val code: String    )

/**
 * Create an invite code.
 *
 * Endpoint: com.atproto.server.createInviteCode
 */
suspend fun ATProtoClient.Com.Atproto.Server.createInviteCode(
input: ComAtprotoServerCreateInviteCodeInput): ATProtoResponse<ComAtprotoServerCreateInviteCodeOutput> {
    val endpoint = "com.atproto.server.createInviteCode"

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
