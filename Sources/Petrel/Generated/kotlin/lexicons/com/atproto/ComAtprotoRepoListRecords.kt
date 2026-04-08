// Lexicon: 1, ID: com.atproto.repo.listRecords
// List a range of records in a repository, matching a specific collection. Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoRepoListRecordsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.repo.listRecords"
}

    @Serializable
    data class ComAtprotoRepoListRecordsRecord(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("value")
        val value: JsonElement    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoRepoListRecordsRecord"
        }
    }

@Serializable
    data class ComAtprotoRepoListRecordsParameters(
// The handle or DID of the repo.        @SerialName("repo")
        val repo: ATIdentifier,// The NSID of the record type.        @SerialName("collection")
        val collection: NSID,// The number of records to return.        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null,// Flag to reverse the order of the returned records.        @SerialName("reverse")
        val reverse: Boolean? = null    )

    @Serializable
    data class ComAtprotoRepoListRecordsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("records")
        val records: List<ComAtprotoRepoListRecordsRecord>    )

/**
 * List a range of records in a repository, matching a specific collection. Does not require auth.
 *
 * Endpoint: com.atproto.repo.listRecords
 */
suspend fun ATProtoClient.Com.Atproto.Repo.listRecords(
parameters: ComAtprotoRepoListRecordsParameters): ATProtoResponse<ComAtprotoRepoListRecordsOutput> {
    val endpoint = "com.atproto.repo.listRecords"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
