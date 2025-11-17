// Lexicon: 1, ID: com.atproto.temp.addReservedHandle
// Add a handle to the set of reserved handles.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoTempAddreservedhandle {
    const val TYPE_IDENTIFIER = "com.atproto.temp.addReservedHandle"

    @Serializable
    data class Input(
        @SerialName("handle")
        val handle: String    )

        @Serializable
    data class Output(
    )

}

/**
 * Add a handle to the set of reserved handles.
 *
 * Endpoint: com.atproto.temp.addReservedHandle
 */
suspend fun ATProtoClient.Com.Atproto.Temp.addreservedhandle(
input: ComAtprotoTempAddreservedhandle.Input): ATProtoResponse<ComAtprotoTempAddreservedhandle.Output> {
    val endpoint = "com.atproto.temp.addReservedHandle"

    // JSON serialization
    val body = Json.encodeToString(input)
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
