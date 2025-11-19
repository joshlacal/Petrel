// Lexicon: 1, ID: com.atproto.temp.dereferenceScope
// Allows finding the oauth permission scope from a reference
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoTempDereferencescope {
    const val TYPE_IDENTIFIER = "com.atproto.temp.dereferenceScope"

    @Serializable
    data class Parameters(
// The scope reference (starts with 'ref:')        @SerialName("scope")
        val scope: String    )

        @Serializable
    data class Output(
// The full oauth permission scope        @SerialName("scope")
        val scope: String    )

    sealed class Error(val name: String, val description: String?) {
        object Invalidscopereference: Error("InvalidScopeReference", "An invalid scope reference was provided.")
    }

}

/**
 * Allows finding the oauth permission scope from a reference
 *
 * Endpoint: com.atproto.temp.dereferenceScope
 */
suspend fun ATProtoClient.Com.Atproto.Temp.dereferencescope(
parameters: ComAtprotoTempDereferencescope.Parameters): ATProtoResponse<ComAtprotoTempDereferencescope.Output> {
    val endpoint = "com.atproto.temp.dereferenceScope"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
