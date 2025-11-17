// Lexicon: 1, ID: com.atproto.identity.updateHandle
// Updates the current account's handle. Verifies handle validity, and updates did:plc document if necessary. Implemented by PDS, and requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoIdentityUpdatehandle {
    const val TYPE_IDENTIFIER = "com.atproto.identity.updateHandle"

    @Serializable
    data class Input(
// The new handle.        @SerialName("handle")
        val handle: Handle    )

}

/**
 * Updates the current account's handle. Verifies handle validity, and updates did:plc document if necessary. Implemented by PDS, and requires auth.
 *
 * Endpoint: com.atproto.identity.updateHandle
 */
suspend fun ATProtoClient.Com.Atproto.Identity.updatehandle(
input: ComAtprotoIdentityUpdatehandle.Input): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.identity.updateHandle"

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
