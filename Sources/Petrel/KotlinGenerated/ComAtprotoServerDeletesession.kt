// Lexicon: 1, ID: com.atproto.server.deleteSession
// Delete the current session. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerDeletesession {
    const val TYPE_IDENTIFIER = "com.atproto.server.deleteSession"

}

/**
 * Delete the current session. Requires auth.
 *
 * Endpoint: com.atproto.server.deleteSession
 */
suspend fun ATProtoClient.Com.Atproto.Server.deletesession(
): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.deleteSession"

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
