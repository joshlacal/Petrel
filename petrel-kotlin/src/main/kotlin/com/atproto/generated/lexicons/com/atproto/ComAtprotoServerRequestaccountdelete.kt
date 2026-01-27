// Lexicon: 1, ID: com.atproto.server.requestAccountDelete
// Initiate a user account deletion via email.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerRequestAccountDeleteDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.requestAccountDelete"
}

/**
 * Initiate a user account deletion via email.
 *
 * Endpoint: com.atproto.server.requestAccountDelete
 */
suspend fun ATProtoClient.Com.Atproto.Server.requestAccountDelete(
): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.requestAccountDelete"

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
