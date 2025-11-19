// Lexicon: 1, ID: com.atproto.sync.listReposByCollection
// Enumerates all the DIDs which have records with the given collection NSID.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoSyncListreposbycollection {
    const val TYPE_IDENTIFIER = "com.atproto.sync.listReposByCollection"

    @Serializable
    data class Parameters(
        @SerialName("collection")
        val collection: NSID,// Maximum size of response set. Recommend setting a large maximum (1000+) when enumerating large DID lists.        @SerialName("limit")
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
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#repo"
        }
    }

}

/**
 * Enumerates all the DIDs which have records with the given collection NSID.
 *
 * Endpoint: com.atproto.sync.listReposByCollection
 */
suspend fun ATProtoClient.Com.Atproto.Sync.listreposbycollection(
parameters: ComAtprotoSyncListreposbycollection.Parameters): ATProtoResponse<ComAtprotoSyncListreposbycollection.Output> {
    val endpoint = "com.atproto.sync.listReposByCollection"

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
