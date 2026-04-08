// Lexicon: 1, ID: blue.catbird.mlsChat.getKeyPackages
// Retrieve key packages for one or more DIDs to add them to conversations
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetKeyPackagesDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getKeyPackages"
}

@Serializable
    data class BlueCatbirdMlsChatGetKeyPackagesParameters(
// DIDs to fetch key packages for        @SerialName("dids")
        val dids: List<DID>,// Filter by cipher suite        @SerialName("cipherSuite")
        val cipherSuite: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatGetKeyPackagesOutput(
// Available key packages for the requested DIDs        @SerialName("keyPackages")
        val keyPackages: List<BlueCatbirdMlsChatDefsKeyPackageRef>,// DIDs for which no key packages were found        @SerialName("missing")
        val missing: List<DID>? = null    )

sealed class BlueCatbirdMlsChatGetKeyPackagesError(val name: String, val description: String?) {
        object TooManyDids: BlueCatbirdMlsChatGetKeyPackagesError("TooManyDids", "Too many DIDs requested")
        object InvalidDid: BlueCatbirdMlsChatGetKeyPackagesError("InvalidDid", "One or more DIDs are invalid")
    }

/**
 * Retrieve key packages for one or more DIDs to add them to conversations
 *
 * Endpoint: blue.catbird.mlsChat.getKeyPackages
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getKeyPackages(
parameters: BlueCatbirdMlsChatGetKeyPackagesParameters): ATProtoResponse<BlueCatbirdMlsChatGetKeyPackagesOutput> {
    val endpoint = "blue.catbird.mlsChat.getKeyPackages"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
