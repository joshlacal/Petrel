// Lexicon: 1, ID: com.atproto.admin.updateAccountPassword
// Update the password for a user account as an administrator.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoAdminUpdateaccountpassword {
    const val TYPE_IDENTIFIER = "com.atproto.admin.updateAccountPassword"

    @Serializable
    data class Input(
        @SerialName("did")
        val did: DID,        @SerialName("password")
        val password: String    )

}

/**
 * Update the password for a user account as an administrator.
 *
 * Endpoint: com.atproto.admin.updateAccountPassword
 */
suspend fun ATProtoClient.Com.Atproto.Admin.updateaccountpassword(
input: ComAtprotoAdminUpdateaccountpassword.Input): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.admin.updateAccountPassword"

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
