// Lexicon: 1, ID: com.atproto.sync.listReposByCollection
// Enumerates all the DIDs which have records with the given collection NSID.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoSyncListReposByCollectionDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.listReposByCollection"
}

    @Serializable
    data class ComAtprotoSyncListReposByCollectionRepo(
        @SerialName("did")
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoSyncListReposByCollectionRepo"
        }
    }

@Serializable
    data class ComAtprotoSyncListReposByCollectionParameters(
        @SerialName("collection")
        val collection: NSID,// Maximum size of response set. Recommend setting a large maximum (1000+) when enumerating large DID lists.        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ComAtprotoSyncListReposByCollectionOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("repos")
        val repos: List<ComAtprotoSyncListReposByCollectionRepo>    )

/**
 * Enumerates all the DIDs which have records with the given collection NSID.
 *
 * Endpoint: com.atproto.sync.listReposByCollection
 */
suspend fun ATProtoClient.Com.Atproto.Sync.listReposByCollection(
parameters: ComAtprotoSyncListReposByCollectionParameters): ATProtoResponse<ComAtprotoSyncListReposByCollectionOutput> {
    val endpoint = "com.atproto.sync.listReposByCollection"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
