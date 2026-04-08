// Lexicon: 1, ID: com.atproto.sync.getRecord
// Get data blocks needed to prove the existence or non-existence of record in the current version of repo. Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoSyncGetRecordDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getRecord"
}

@Serializable
    data class ComAtprotoSyncGetRecordParameters(
// The DID of the repo.        @SerialName("did")
        val did: DID,        @SerialName("collection")
        val collection: NSID,// Record Key        @SerialName("rkey")
        val rkey: String    )

    @Serializable
    data class ComAtprotoSyncGetRecordOutput(
        @SerialName("data")
        val `data`: ByteArray    )

sealed class ComAtprotoSyncGetRecordError(val name: String, val description: String?) {
        object RecordNotFound: ComAtprotoSyncGetRecordError("RecordNotFound", "")
        object RepoNotFound: ComAtprotoSyncGetRecordError("RepoNotFound", "")
        object RepoTakendown: ComAtprotoSyncGetRecordError("RepoTakendown", "")
        object RepoSuspended: ComAtprotoSyncGetRecordError("RepoSuspended", "")
        object RepoDeactivated: ComAtprotoSyncGetRecordError("RepoDeactivated", "")
    }

/**
 * Get data blocks needed to prove the existence or non-existence of record in the current version of repo. Does not require auth.
 *
 * Endpoint: com.atproto.sync.getRecord
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getRecord(
parameters: ComAtprotoSyncGetRecordParameters): ATProtoResponse<ComAtprotoSyncGetRecordOutput> {
    val endpoint = "com.atproto.sync.getRecord"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/vnd.ipld.car"),
        body = null
    )
}
