// Lexicon: 1, ID: com.atproto.identity.getRecommendedDidCredentials
// Describe the credentials that should be included in the DID doc of an account that is migrating to this service.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
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

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
