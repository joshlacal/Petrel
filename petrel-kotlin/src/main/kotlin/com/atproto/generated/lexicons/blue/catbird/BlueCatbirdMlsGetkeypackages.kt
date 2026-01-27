// Lexicon: 1, ID: blue.catbird.mls.getKeyPackages
// Retrieve key packages for one or more DIDs to add them to conversations
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetKeyPackagesDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getKeyPackages"
}

@Serializable
    data class BlueCatbirdMlsGetKeyPackagesParameters(
// DIDs to fetch key packages for        @SerialName("dids")
        val dids: List<DID>,// Filter by cipher suite        @SerialName("cipherSuite")
        val cipherSuite: String? = null    )

    @Serializable
    data class BlueCatbirdMlsGetKeyPackagesOutput(
// Available key packages for the requested DIDs        @SerialName("keyPackages")
        val keyPackages: List<BlueCatbirdMlsDefsKeyPackageRef>,// DIDs for which no key packages were found        @SerialName("missing")
        val missing: List<DID>? = null    )

sealed class BlueCatbirdMlsGetKeyPackagesError(val name: String, val description: String?) {
        object TooManyDids: BlueCatbirdMlsGetKeyPackagesError("TooManyDids", "Too many DIDs requested")
        object InvalidDid: BlueCatbirdMlsGetKeyPackagesError("InvalidDid", "One or more DIDs are invalid")
    }

/**
 * Retrieve key packages for one or more DIDs to add them to conversations
 *
 * Endpoint: blue.catbird.mls.getKeyPackages
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getKeyPackages(
parameters: BlueCatbirdMlsGetKeyPackagesParameters): ATProtoResponse<BlueCatbirdMlsGetKeyPackagesOutput> {
    val endpoint = "blue.catbird.mls.getKeyPackages"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
