// Lexicon: 1, ID: com.atproto.sync.listRepos
// Enumerates all the DID, rev, and commit CID for all repos hosted by this service. Does not require auth; implemented by PDS and Relay.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoSyncListrepos {
    const val TYPE_IDENTIFIER = "com.atproto.sync.listRepos"

    @Serializable
    data class Parameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("repos")
        val repos: List<Repo>    )

        @Serializable
    data class Repo(
        @SerialName("did")
        val did: DID,/** Current repo commit CID */        @SerialName("head")
        val head: CID,        @SerialName("rev")
        val rev: String,        @SerialName("active")
        val active: Boolean?,/** If active=false, this optional field indicates a possible reason for why the account is not active. If active=false and no status is supplied, then the host makes no claim for why the repository is no longer being hosted. */        @SerialName("status")
        val status: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#repo"
        }
    }

}

/**
 * Enumerates all the DID, rev, and commit CID for all repos hosted by this service. Does not require auth; implemented by PDS and Relay.
 *
 * Endpoint: com.atproto.sync.listRepos
 */
suspend fun ATProtoClient.Com.Atproto.Sync.listrepos(
parameters: ComAtprotoSyncListrepos.Parameters): ATProtoResponse<ComAtprotoSyncListrepos.Output> {
    val endpoint = "com.atproto.sync.listRepos"

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
