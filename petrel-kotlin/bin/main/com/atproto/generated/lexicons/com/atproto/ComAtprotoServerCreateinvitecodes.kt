// Lexicon: 1, ID: com.atproto.server.createInviteCodes
// Create invite codes.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerCreateInviteCodesDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.createInviteCodes"
}

    @Serializable
    data class ComAtprotoServerCreateInviteCodesAccountCodes(
        @SerialName("account")
        val account: String,        @SerialName("codes")
        val codes: List<String>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoServerCreateInviteCodesAccountCodes"
        }
    }

@Serializable
    data class ComAtprotoServerCreateInviteCodesInput(
        @SerialName("codeCount")
        val codeCount: Int,        @SerialName("useCount")
        val useCount: Int,        @SerialName("forAccounts")
        val forAccounts: List<DID>? = null    )

    @Serializable
    data class ComAtprotoServerCreateInviteCodesOutput(
        @SerialName("codes")
        val codes: List<ComAtprotoServerCreateInviteCodesAccountCodes>    )

/**
 * Create invite codes.
 *
 * Endpoint: com.atproto.server.createInviteCodes
 */
suspend fun ATProtoClient.Com.Atproto.Server.createInviteCodes(
input: ComAtprotoServerCreateInviteCodesInput): ATProtoResponse<ComAtprotoServerCreateInviteCodesOutput> {
    val endpoint = "com.atproto.server.createInviteCodes"

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
