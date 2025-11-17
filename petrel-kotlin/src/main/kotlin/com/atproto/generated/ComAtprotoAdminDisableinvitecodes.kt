// Lexicon: 1, ID: com.atproto.admin.disableInviteCodes
// Disable some set of codes and/or all codes associated with a set of users.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoAdminDisableinvitecodes {
    const val TYPE_IDENTIFIER = "com.atproto.admin.disableInviteCodes"

    @Serializable
    data class Input(
        @SerialName("codes")
        val codes: List<String>? = null,        @SerialName("accounts")
        val accounts: List<String>? = null    )

}

/**
 * Disable some set of codes and/or all codes associated with a set of users.
 *
 * Endpoint: com.atproto.admin.disableInviteCodes
 */
suspend fun ATProtoClient.Com.Atproto.Admin.disableinvitecodes(
input: ComAtprotoAdminDisableinvitecodes.Input): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.admin.disableInviteCodes"

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
