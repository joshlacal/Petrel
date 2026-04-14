// Lexicon: 1, ID: blue.catbird.mlsDS.deleteFederationPeer
// Delete a federation peer policy (admin only). Remove a federation peer policy record. Requires federation admin privileges.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsDSDeleteFederationPeerDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsDS.deleteFederationPeer"
}

@Serializable
    data class BlueCatbirdMlsDSDeleteFederationPeerInput(
// DID of the peer delivery service to remove        @SerialName("dsDid")
        val dsDid: String    )

    @Serializable
    data class BlueCatbirdMlsDSDeleteFederationPeerOutput(
// Whether the peer was deleted        @SerialName("deleted")
        val deleted: Boolean,// DID that was deleted        @SerialName("dsDid")
        val dsDid: String    )

/**
 * Delete a federation peer policy (admin only). Remove a federation peer policy record. Requires federation admin privileges.
 *
 * Endpoint: blue.catbird.mlsDS.deleteFederationPeer
 */
suspend fun ATProtoClient.Blue.Catbird.MlsDS.deleteFederationPeer(
input: BlueCatbirdMlsDSDeleteFederationPeerInput): ATProtoResponse<BlueCatbirdMlsDSDeleteFederationPeerOutput> {
    val endpoint = "blue.catbird.mlsDS.deleteFederationPeer"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
