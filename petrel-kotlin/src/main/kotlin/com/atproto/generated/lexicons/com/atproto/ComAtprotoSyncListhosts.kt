// Lexicon: 1, ID: com.atproto.sync.listHosts
// Enumerates upstream hosts (eg, PDS or relay instances) that this service consumes from. Implemented by relays.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoSyncListHostsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.listHosts"
}

    @Serializable
    data class ComAtprotoSyncListHostsHost(
/** hostname of server; not a URL (no scheme) */        @SerialName("hostname")
        val hostname: String,/** Recent repo stream event sequence number. May be delayed from actual stream processing (eg, persisted cursor not in-memory cursor). */        @SerialName("seq")
        val seq: Int?,        @SerialName("accountCount")
        val accountCount: Int?,        @SerialName("status")
        val status: ComAtprotoSyncDefsHostStatus?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoSyncListHostsHost"
        }
    }

@Serializable
    data class ComAtprotoSyncListHostsParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ComAtprotoSyncListHostsOutput(
        @SerialName("cursor")
        val cursor: String? = null,// Sort order is not formally specified. Recommended order is by time host was first seen by the server, with oldest first.        @SerialName("hosts")
        val hosts: List<ComAtprotoSyncListHostsHost>    )

/**
 * Enumerates upstream hosts (eg, PDS or relay instances) that this service consumes from. Implemented by relays.
 *
 * Endpoint: com.atproto.sync.listHosts
 */
suspend fun ATProtoClient.Com.Atproto.Sync.listHosts(
parameters: ComAtprotoSyncListHostsParameters): ATProtoResponse<ComAtprotoSyncListHostsOutput> {
    val endpoint = "com.atproto.sync.listHosts"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
