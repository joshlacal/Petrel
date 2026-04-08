// Lexicon: 1, ID: com.atproto.repo.getRecord
// Get a single record from a repository. Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoRepoGetRecordDefs {
    const val TYPE_IDENTIFIER = "com.atproto.repo.getRecord"
}

@Serializable
    data class ComAtprotoRepoGetRecordParameters(
// The handle or DID of the repo.        @SerialName("repo")
        val repo: ATIdentifier,// The NSID of the record collection.        @SerialName("collection")
        val collection: NSID,// The Record Key.        @SerialName("rkey")
        val rkey: String,// The CID of the version of the record. If not specified, then return the most recent version.        @SerialName("cid")
        val cid: CID? = null    )

    @Serializable
    data class ComAtprotoRepoGetRecordOutput(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID? = null,        @SerialName("value")
        val value: JsonElement    )

sealed class ComAtprotoRepoGetRecordError(val name: String, val description: String?) {
        object RecordNotFound: ComAtprotoRepoGetRecordError("RecordNotFound", "")
    }

/**
 * Get a single record from a repository. Does not require auth.
 *
 * Endpoint: com.atproto.repo.getRecord
 */
suspend fun ATProtoClient.Com.Atproto.Repo.getRecord(
parameters: ComAtprotoRepoGetRecordParameters): ATProtoResponse<ComAtprotoRepoGetRecordOutput> {
    val endpoint = "com.atproto.repo.getRecord"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
