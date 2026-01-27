// Lexicon: 1, ID: com.atproto.server.requestEmailConfirmation
// Request an email with a code to confirm ownership of email.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerRequestEmailConfirmationDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.requestEmailConfirmation"
}

/**
 * Request an email with a code to confirm ownership of email.
 *
 * Endpoint: com.atproto.server.requestEmailConfirmation
 */
suspend fun ATProtoClient.Com.Atproto.Server.requestEmailConfirmation(
): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.requestEmailConfirmation"

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
