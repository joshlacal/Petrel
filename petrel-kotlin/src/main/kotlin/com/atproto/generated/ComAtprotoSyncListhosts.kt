// Lexicon: 1, ID: com.atproto.sync.listHosts
// Enumerates upstream hosts (eg, PDS or relay instances) that this service consumes from. Implemented by relays.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoSyncListhosts {
    const val TYPE_IDENTIFIER = "com.atproto.sync.listHosts"

    @Serializable
    data class Parameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,// Sort order is not formally specified. Recommended order is by time host was first seen by the server, with oldest first.        @SerialName("hosts")
        val hosts: List<Host>    )

        @Serializable
    data class Host(
/** hostname of server; not a URL (no scheme) */        @SerialName("hostname")
        val hostname: String,/** Recent repo stream event sequence number. May be delayed from actual stream processing (eg, persisted cursor not in-memory cursor). */        @SerialName("seq")
        val seq: Int?,        @SerialName("accountCount")
        val accountCount: Int?,        @SerialName("status")
        val status: ComAtprotoSyncDefs.Hoststatus?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#host"
        }
    }

}

/**
 * Enumerates upstream hosts (eg, PDS or relay instances) that this service consumes from. Implemented by relays.
 *
 * Endpoint: com.atproto.sync.listHosts
 */
suspend fun ATProtoClient.Com.Atproto.Sync.listhosts(
parameters: ComAtprotoSyncListhosts.Parameters): ATProtoResponse<ComAtprotoSyncListhosts.Output> {
    val endpoint = "com.atproto.sync.listHosts"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
