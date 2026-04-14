// Lexicon: 1, ID: blue.catbird.mlsDS.upsertFederationPeer
// Create or update a federation peer policy (admin only). Upsert a federation peer policy record. Requires federation admin privileges.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsDSUpsertFederationPeerDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsDS.upsertFederationPeer"
}

@Serializable
    data class BlueCatbirdMlsDSUpsertFederationPeerInput(
// DID of the peer delivery service        @SerialName("dsDid")
        val dsDid: String,// Peer status to set (trusted, blocked, probation)        @SerialName("status")
        val status: String,// Per-peer rate limit override        @SerialName("maxRequestsPerMinute")
        val maxRequestsPerMinute: Int? = null,// Admin note        @SerialName("note")
        val note: String? = null    )

    @Serializable
    data class BlueCatbirdMlsDSUpsertFederationPeerOutput(
// Whether the upsert succeeded        @SerialName("updated")
        val updated: Boolean,        @SerialName("peer")
        val peer: BlueCatbirdMlsDSGetFederationPeersPeerRecord    )

/**
 * Create or update a federation peer policy (admin only). Upsert a federation peer policy record. Requires federation admin privileges.
 *
 * Endpoint: blue.catbird.mlsDS.upsertFederationPeer
 */
suspend fun ATProtoClient.Blue.Catbird.MlsDS.upsertFederationPeer(
input: BlueCatbirdMlsDSUpsertFederationPeerInput): ATProtoResponse<BlueCatbirdMlsDSUpsertFederationPeerOutput> {
    val endpoint = "blue.catbird.mlsDS.upsertFederationPeer"

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
