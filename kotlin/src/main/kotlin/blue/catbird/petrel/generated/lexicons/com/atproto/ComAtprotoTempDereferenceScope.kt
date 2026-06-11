// Lexicon: 1, ID: com.atproto.temp.dereferenceScope
// Allows finding the oauth permission scope from a reference
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
