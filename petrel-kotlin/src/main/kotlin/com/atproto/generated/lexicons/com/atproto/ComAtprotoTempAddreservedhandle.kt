// Lexicon: 1, ID: com.atproto.temp.addReservedHandle
// Add a handle to the set of reserved handles.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoTempAddReservedHandleDefs {
    const val TYPE_IDENTIFIER = "com.atproto.temp.addReservedHandle"
}

@Serializable
    data class ComAtprotoTempAddReservedHandleInput(
        @SerialName("handle")
        val handle: String    )

    @Serializable
    class ComAtprotoTempAddReservedHandleOutput

/**
 * Add a handle to the set of reserved handles.
 *
 * Endpoint: com.atproto.temp.addReservedHandle
 */
suspend fun ATProtoClient.Com.Atproto.Temp.addReservedHandle(
input: ComAtprotoTempAddReservedHandleInput): ATProtoResponse<ComAtprotoTempAddReservedHandleOutput> {
    val endpoint = "com.atproto.temp.addReservedHandle"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
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
