// Lexicon: 1, ID: com.atproto.admin.enableAccountInvites
// Re-enable an account's ability to receive invite codes.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoAdminEnableaccountinvites {
    const val TYPE_IDENTIFIER = "com.atproto.admin.enableAccountInvites"

    @Serializable
    data class Input(
        @SerialName("account")
        val account: DID,// Optional reason for enabled invites.        @SerialName("note")
        val note: String? = null    )

}

/**
 * Re-enable an account's ability to receive invite codes.
 *
 * Endpoint: com.atproto.admin.enableAccountInvites
 */
suspend fun ATProtoClient.Com.Atproto.Admin.enableaccountinvites(
input: ComAtprotoAdminEnableaccountinvites.Input): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.admin.enableAccountInvites"

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
