// Lexicon: 1, ID: com.atproto.admin.updateAccountSigningKey
// Administrative action to update an account's signing key in their Did document.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoAdminUpdateaccountsigningkey {
    const val TYPE_IDENTIFIER = "com.atproto.admin.updateAccountSigningKey"

    @Serializable
    data class Input(
        @SerialName("did")
        val did: DID,// Did-key formatted public key        @SerialName("signingKey")
        val signingKey: DID    )

}

/**
 * Administrative action to update an account's signing key in their Did document.
 *
 * Endpoint: com.atproto.admin.updateAccountSigningKey
 */
suspend fun ATProtoClient.Com.Atproto.Admin.updateaccountsigningkey(
input: ComAtprotoAdminUpdateaccountsigningkey.Input): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.admin.updateAccountSigningKey"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
