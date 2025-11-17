// Lexicon: 1, ID: com.atproto.temp.checkSignupQueue
// Check accounts location in signup queue.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoTempChecksignupqueue {
    const val TYPE_IDENTIFIER = "com.atproto.temp.checkSignupQueue"

        @Serializable
    data class Output(
        @SerialName("activated")
        val activated: Boolean,        @SerialName("placeInQueue")
        val placeInQueue: Int? = null,        @SerialName("estimatedTimeMs")
        val estimatedTimeMs: Int? = null    )

}

/**
 * Check accounts location in signup queue.
 *
 * Endpoint: com.atproto.temp.checkSignupQueue
 */
suspend fun ATProtoClient.Com.Atproto.Temp.checksignupqueue(
): ATProtoResponse<ComAtprotoTempChecksignupqueue.Output> {
    val endpoint = "com.atproto.temp.checkSignupQueue"

    val queryParams: Map<String, String>? = null

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
