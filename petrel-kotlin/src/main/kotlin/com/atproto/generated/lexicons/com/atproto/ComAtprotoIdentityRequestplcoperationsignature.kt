// Lexicon: 1, ID: com.atproto.identity.requestPlcOperationSignature
// Request an email with a code to in order to request a signed PLC operation. Requires Auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoIdentityRequestPlcOperationSignatureDefs {
    const val TYPE_IDENTIFIER = "com.atproto.identity.requestPlcOperationSignature"
}

/**
 * Request an email with a code to in order to request a signed PLC operation. Requires Auth.
 *
 * Endpoint: com.atproto.identity.requestPlcOperationSignature
 */
suspend fun ATProtoClient.Com.Atproto.Identity.requestPlcOperationSignature(
): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.identity.requestPlcOperationSignature"

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
