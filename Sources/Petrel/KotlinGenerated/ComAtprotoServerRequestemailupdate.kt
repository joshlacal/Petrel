// Lexicon: 1, ID: com.atproto.server.requestEmailUpdate
// Request a token in order to update email.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerRequestemailupdate {
    const val TYPE_IDENTIFIER = "com.atproto.server.requestEmailUpdate"

        @Serializable
    data class Output(
        @SerialName("tokenRequired")
        val tokenRequired: Boolean    )

}

/**
 * Request a token in order to update email.
 *
 * Endpoint: com.atproto.server.requestEmailUpdate
 */
suspend fun ATProtoClient.Com.Atproto.Server.requestemailupdate(
): ATProtoResponse<ComAtprotoServerRequestemailupdate.Output> {
    val endpoint = "com.atproto.server.requestEmailUpdate"

    val body: String? = null
    val contentType = "application/json"

    return networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
