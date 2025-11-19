// Lexicon: 1, ID: com.atproto.identity.requestPlcOperationSignature
// Request an email with a code to in order to request a signed PLC operation. Requires Auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoIdentityRequestplcoperationsignature {
    const val TYPE_IDENTIFIER = "com.atproto.identity.requestPlcOperationSignature"

}

/**
 * Request an email with a code to in order to request a signed PLC operation. Requires Auth.
 *
 * Endpoint: com.atproto.identity.requestPlcOperationSignature
 */
suspend fun ATProtoClient.Com.Atproto.Identity.requestplcoperationsignature(
): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.identity.requestPlcOperationSignature"

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
