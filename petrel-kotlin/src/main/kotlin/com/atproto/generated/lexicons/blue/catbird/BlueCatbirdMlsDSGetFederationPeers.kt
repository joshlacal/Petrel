// Lexicon: 1, ID: blue.catbird.mlsDS.getFederationPeers
// List federation peer policies (admin only). Return a list of known federation peer DS policies, optionally filtered by status.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsDSGetFederationPeersDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsDS.getFederationPeers"
}

    /**
     * Federation peer policy record.
     */
    @Serializable
    data class BlueCatbirdMlsDSGetFederationPeersPeerRecord(
/** DID of the peer delivery service */        @SerialName("dsDid")
        val dsDid: String,/** Peer status (trusted, blocked, probation, unknown) */        @SerialName("status")
        val status: String,/** Computed trust score */        @SerialName("trustScore")
        val trustScore: Int? = null,/** Per-peer rate limit override */        @SerialName("maxRequestsPerMinute")
        val maxRequestsPerMinute: Int? = null,/** Admin note */        @SerialName("note")
        val note: String? = null,        @SerialName("invalidTokenCount")
        val invalidTokenCount: Int? = null,        @SerialName("rejectedRequestCount")
        val rejectedRequestCount: Int? = null,        @SerialName("successfulRequestCount")
        val successfulRequestCount: Int? = null,        @SerialName("lastSeenAt")
        val lastSeenAt: ATProtocolDate? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate? = null,        @SerialName("updatedAt")
        val updatedAt: ATProtocolDate? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsDSGetFederationPeersPeerRecord"
        }
    }

@Serializable
    data class BlueCatbirdMlsDSGetFederationPeersParameters(
// Filter by peer status (e.g., 'trusted', 'blocked', 'probation')        @SerialName("status")
        val status: String? = null,// Maximum number of peers to return (default 100)        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsDSGetFederationPeersOutput(
// List of peer records        @SerialName("peers")
        val peers: List<BlueCatbirdMlsDSGetFederationPeersPeerRecord>    )

/**
 * List federation peer policies (admin only). Return a list of known federation peer DS policies, optionally filtered by status.
 *
 * Endpoint: blue.catbird.mlsDS.getFederationPeers
 */
suspend fun ATProtoClient.Blue.Catbird.MlsDS.getFederationPeers(
parameters: BlueCatbirdMlsDSGetFederationPeersParameters): ATProtoResponse<BlueCatbirdMlsDSGetFederationPeersOutput> {
    val endpoint = "blue.catbird.mlsDS.getFederationPeers"

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
