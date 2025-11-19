// Lexicon: 1, ID: com.atproto.sync.getHostStatus
// Returns information about a specified upstream host, as consumed by the server. Implemented by relays.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoSyncGethoststatus {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getHostStatus"

    @Serializable
    data class Parameters(
// Hostname of the host (eg, PDS or relay) being queried.        @SerialName("hostname")
        val hostname: String    )

        @Serializable
    data class Output(
        @SerialName("hostname")
        val hostname: String,// Recent repo stream event sequence number. May be delayed from actual stream processing (eg, persisted cursor not in-memory cursor).        @SerialName("seq")
        val seq: Int? = null,// Number of accounts on the server which are associated with the upstream host. Note that the upstream may actually have more accounts.        @SerialName("accountCount")
        val accountCount: Int? = null,        @SerialName("status")
        val status: ComAtprotoSyncDefs.Hoststatus? = null    )

    sealed class Error(val name: String, val description: String?) {
        object Hostnotfound: Error("HostNotFound", "")
    }

}

/**
 * Returns information about a specified upstream host, as consumed by the server. Implemented by relays.
 *
 * Endpoint: com.atproto.sync.getHostStatus
 */
suspend fun ATProtoClient.Com.Atproto.Sync.gethoststatus(
parameters: ComAtprotoSyncGethoststatus.Parameters): ATProtoResponse<ComAtprotoSyncGethoststatus.Output> {
    val endpoint = "com.atproto.sync.getHostStatus"

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
