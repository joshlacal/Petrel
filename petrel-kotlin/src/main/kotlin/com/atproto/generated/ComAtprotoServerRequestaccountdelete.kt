// Lexicon: 1, ID: com.atproto.server.requestAccountDelete
// Initiate a user account deletion via email.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerRequestaccountdelete {
    const val TYPE_IDENTIFIER = "com.atproto.server.requestAccountDelete"

}

/**
 * Initiate a user account deletion via email.
 *
 * Endpoint: com.atproto.server.requestAccountDelete
 */
suspend fun ATProtoClient.Com.Atproto.Server.requestaccountdelete(
): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.requestAccountDelete"

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
