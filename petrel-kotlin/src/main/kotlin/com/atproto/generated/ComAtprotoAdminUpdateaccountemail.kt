// Lexicon: 1, ID: com.atproto.admin.updateAccountEmail
// Administrative action to update an account's email.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoAdminUpdateaccountemail {
    const val TYPE_IDENTIFIER = "com.atproto.admin.updateAccountEmail"

    @Serializable
    data class Input(
// The handle or DID of the repo.        @SerialName("account")
        val account: ATIdentifier,        @SerialName("email")
        val email: String    )

}

/**
 * Administrative action to update an account's email.
 *
 * Endpoint: com.atproto.admin.updateAccountEmail
 */
suspend fun ATProtoClient.Com.Atproto.Admin.updateaccountemail(
input: ComAtprotoAdminUpdateaccountemail.Input): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.admin.updateAccountEmail"

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
