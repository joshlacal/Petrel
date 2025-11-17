// Lexicon: 1, ID: com.atproto.server.createInviteCodes
// Create invite codes.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerCreateinvitecodes {
    const val TYPE_IDENTIFIER = "com.atproto.server.createInviteCodes"

    @Serializable
    data class Input(
        @SerialName("codeCount")
        val codeCount: Int,        @SerialName("useCount")
        val useCount: Int,        @SerialName("forAccounts")
        val forAccounts: List<DID>? = null    )

        @Serializable
    data class Output(
        @SerialName("codes")
        val codes: List<Accountcodes>    )

        @Serializable
    data class Accountcodes(
        @SerialName("account")
        val account: String,        @SerialName("codes")
        val codes: List<String>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#accountcodes"
        }
    }

}

/**
 * Create invite codes.
 *
 * Endpoint: com.atproto.server.createInviteCodes
 */
suspend fun ATProtoClient.Com.Atproto.Server.createinvitecodes(
input: ComAtprotoServerCreateinvitecodes.Input): ATProtoResponse<ComAtprotoServerCreateinvitecodes.Output> {
    val endpoint = "com.atproto.server.createInviteCodes"

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
