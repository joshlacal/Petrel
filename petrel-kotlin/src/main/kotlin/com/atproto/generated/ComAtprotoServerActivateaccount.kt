// Lexicon: 1, ID: com.atproto.server.activateAccount
// Activates a currently deactivated account. Used to finalize account migration after the account's repo is imported and identity is setup.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerActivateaccount {
    const val TYPE_IDENTIFIER = "com.atproto.server.activateAccount"

}

/**
 * Activates a currently deactivated account. Used to finalize account migration after the account's repo is imported and identity is setup.
 *
 * Endpoint: com.atproto.server.activateAccount
 */
suspend fun ATProtoClient.Com.Atproto.Server.activateaccount(
): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.activateAccount"

    val body: String? = null
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
