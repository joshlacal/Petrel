// Lexicon: 1, ID: com.atproto.server.deleteSession
// Delete the current session. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerDeleteSessionDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.deleteSession"
}

/**
 * Delete the current session. Requires auth.
 *
 * Endpoint: com.atproto.server.deleteSession
 */
suspend fun ATProtoClient.Com.Atproto.Server.deleteSession(
): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.deleteSession"

    val body: String? = null
    val contentType = "application/json"

    return client.networkService.performRequest(
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
