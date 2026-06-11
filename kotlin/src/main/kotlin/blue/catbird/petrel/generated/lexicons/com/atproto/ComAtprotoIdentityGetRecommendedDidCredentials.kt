// Lexicon: 1, ID: com.atproto.identity.getRecommendedDidCredentials
// Describe the credentials that should be included in the DID doc of an account that is migrating to this service.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoIdentityGetRecommendedDidCredentialsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.identity.getRecommendedDidCredentials"
}

    @Serializable
    data class ComAtprotoIdentityGetRecommendedDidCredentialsOutput(
// Recommended rotation keys for PLC dids. Should be undefined (or ignored) for did:webs.        @SerialName("rotationKeys")
        val rotationKeys: List<String>? = null,        @SerialName("alsoKnownAs")
        val alsoKnownAs: List<String>? = null,        @SerialName("verificationMethods")
        val verificationMethods: JsonElement? = null,        @SerialName("services")
        val services: JsonElement? = null    )

/**
 * Describe the credentials that should be included in the DID doc of an account that is migrating to this service.
 *
 * Endpoint: com.atproto.identity.getRecommendedDidCredentials
 */
suspend fun ATProtoClient.Com.Atproto.Identity.getRecommendedDidCredentials(
): ATProtoResponse<ComAtprotoIdentityGetRecommendedDidCredentialsOutput> {
    val endpoint = "com.atproto.identity.getRecommendedDidCredentials"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
