// Lexicon: 1, ID: com.atproto.temp.checkSignupQueue
// Check accounts location in signup queue.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoTempCheckSignupQueueDefs {
    const val TYPE_IDENTIFIER = "com.atproto.temp.checkSignupQueue"
}

    @Serializable
    data class ComAtprotoTempCheckSignupQueueOutput(
        @SerialName("activated")
        val activated: Boolean,        @SerialName("placeInQueue")
        val placeInQueue: Int? = null,        @SerialName("estimatedTimeMs")
        val estimatedTimeMs: Int? = null    )

/**
 * Check accounts location in signup queue.
 *
 * Endpoint: com.atproto.temp.checkSignupQueue
 */
suspend fun ATProtoClient.Com.Atproto.Temp.checkSignupQueue(
): ATProtoResponse<ComAtprotoTempCheckSignupQueueOutput> {
    val endpoint = "com.atproto.temp.checkSignupQueue"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
