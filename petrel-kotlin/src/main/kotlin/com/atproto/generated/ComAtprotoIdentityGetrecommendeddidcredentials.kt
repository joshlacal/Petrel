// Lexicon: 1, ID: com.atproto.identity.getRecommendedDidCredentials
// Describe the credentials that should be included in the DID doc of an account that is migrating to this service.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoIdentityGetrecommendeddidcredentials {
    const val TYPE_IDENTIFIER = "com.atproto.identity.getRecommendedDidCredentials"

        @Serializable
    data class Output(
// Recommended rotation keys for PLC dids. Should be undefined (or ignored) for did:webs.        @SerialName("rotationKeys")
        val rotationKeys: List<String>? = null,        @SerialName("alsoKnownAs")
        val alsoKnownAs: List<String>? = null,        @SerialName("verificationMethods")
        val verificationMethods: JsonElement? = null,        @SerialName("services")
        val services: JsonElement? = null    )

}

/**
 * Describe the credentials that should be included in the DID doc of an account that is migrating to this service.
 *
 * Endpoint: com.atproto.identity.getRecommendedDidCredentials
 */
suspend fun ATProtoClient.Com.Atproto.Identity.getrecommendeddidcredentials(
): ATProtoResponse<ComAtprotoIdentityGetrecommendeddidcredentials.Output> {
    val endpoint = "com.atproto.identity.getRecommendedDidCredentials"

    val queryParams: Map<String, String>? = null

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
