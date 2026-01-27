// Lexicon: 1, ID: com.atproto.identity.resolveIdentity
// Resolves an identity (DID or Handle) to a full identity (DID document and verified handle).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoIdentityResolveIdentityDefs {
    const val TYPE_IDENTIFIER = "com.atproto.identity.resolveIdentity"
}

@Serializable
    data class ComAtprotoIdentityResolveIdentityParameters(
// Handle or DID to resolve.        @SerialName("identifier")
        val identifier: ATIdentifier    )

    typealias ComAtprotoIdentityResolveIdentityOutput = ComAtprotoIdentityDefsIdentityInfo

sealed class ComAtprotoIdentityResolveIdentityError(val name: String, val description: String?) {
        object HandleNotFound: ComAtprotoIdentityResolveIdentityError("HandleNotFound", "The resolution process confirmed that the handle does not resolve to any DID.")
        object DidNotFound: ComAtprotoIdentityResolveIdentityError("DidNotFound", "The DID resolution process confirmed that there is no current DID.")
        object DidDeactivated: ComAtprotoIdentityResolveIdentityError("DidDeactivated", "The DID previously existed, but has been deactivated.")
    }

/**
 * Resolves an identity (DID or Handle) to a full identity (DID document and verified handle).
 *
 * Endpoint: com.atproto.identity.resolveIdentity
 */
suspend fun ATProtoClient.Com.Atproto.Identity.resolveIdentity(
parameters: ComAtprotoIdentityResolveIdentityParameters): ATProtoResponse<ComAtprotoIdentityResolveIdentityOutput> {
    val endpoint = "com.atproto.identity.resolveIdentity"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
