// Lexicon: 1, ID: com.atproto.sync.getHostStatus
// Returns information about a specified upstream host, as consumed by the server. Implemented by relays.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoSyncGetHostStatusDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getHostStatus"
}

@Serializable
    data class ComAtprotoSyncGetHostStatusParameters(
// Hostname of the host (eg, PDS or relay) being queried.        @SerialName("hostname")
        val hostname: String    )

    @Serializable
    data class ComAtprotoSyncGetHostStatusOutput(
        @SerialName("hostname")
        val hostname: String,// Recent repo stream event sequence number. May be delayed from actual stream processing (eg, persisted cursor not in-memory cursor).        @SerialName("seq")
        val seq: Int? = null,// Number of accounts on the server which are associated with the upstream host. Note that the upstream may actually have more accounts.        @SerialName("accountCount")
        val accountCount: Int? = null,        @SerialName("status")
        val status: ComAtprotoSyncDefsHostStatus? = null    )

sealed class ComAtprotoSyncGetHostStatusError(val name: String, val description: String?) {
        object HostNotFound: ComAtprotoSyncGetHostStatusError("HostNotFound", "")
    }

/**
 * Returns information about a specified upstream host, as consumed by the server. Implemented by relays.
 *
 * Endpoint: com.atproto.sync.getHostStatus
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getHostStatus(
parameters: ComAtprotoSyncGetHostStatusParameters): ATProtoResponse<ComAtprotoSyncGetHostStatusOutput> {
    val endpoint = "com.atproto.sync.getHostStatus"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
