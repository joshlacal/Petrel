// Lexicon: 1, ID: com.atproto.temp.dereferenceScope
// Allows finding the oauth permission scope from a reference
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoTempDereferenceScopeDefs {
    const val TYPE_IDENTIFIER = "com.atproto.temp.dereferenceScope"
}

@Serializable
    data class ComAtprotoTempDereferenceScopeParameters(
// The scope reference (starts with 'ref:')        @SerialName("scope")
        val scope: String    )

    @Serializable
    data class ComAtprotoTempDereferenceScopeOutput(
// The full oauth permission scope        @SerialName("scope")
        val scope: String    )

sealed class ComAtprotoTempDereferenceScopeError(val name: String, val description: String?) {
        object InvalidScopeReference: ComAtprotoTempDereferenceScopeError("InvalidScopeReference", "An invalid scope reference was provided.")
    }

/**
 * Allows finding the oauth permission scope from a reference
 *
 * Endpoint: com.atproto.temp.dereferenceScope
 */
suspend fun ATProtoClient.Com.Atproto.Temp.dereferenceScope(
parameters: ComAtprotoTempDereferenceScopeParameters): ATProtoResponse<ComAtprotoTempDereferenceScopeOutput> {
    val endpoint = "com.atproto.temp.dereferenceScope"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
