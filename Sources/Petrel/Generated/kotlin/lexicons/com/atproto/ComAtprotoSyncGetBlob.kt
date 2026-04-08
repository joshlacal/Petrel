// Lexicon: 1, ID: com.atproto.sync.getBlob
// Get a blob associated with a given account. Returns the full blob as originally uploaded. Does not require auth; implemented by PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoSyncGetBlobDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.getBlob"
}

@Serializable
    data class ComAtprotoSyncGetBlobParameters(
// The DID of the account.        @SerialName("did")
        val did: DID,// The CID of the blob to fetch        @SerialName("cid")
        val cid: CID    )

    @Serializable
    data class ComAtprotoSyncGetBlobOutput(
        @SerialName("data")
        val `data`: ByteArray    )

sealed class ComAtprotoSyncGetBlobError(val name: String, val description: String?) {
        object BlobNotFound: ComAtprotoSyncGetBlobError("BlobNotFound", "")
        object RepoNotFound: ComAtprotoSyncGetBlobError("RepoNotFound", "")
        object RepoTakendown: ComAtprotoSyncGetBlobError("RepoTakendown", "")
        object RepoSuspended: ComAtprotoSyncGetBlobError("RepoSuspended", "")
        object RepoDeactivated: ComAtprotoSyncGetBlobError("RepoDeactivated", "")
    }

/**
 * Get a blob associated with a given account. Returns the full blob as originally uploaded. Does not require auth; implemented by PDS.
 *
 * Endpoint: com.atproto.sync.getBlob
 */
suspend fun ATProtoClient.Com.Atproto.Sync.getBlob(
parameters: ComAtprotoSyncGetBlobParameters): ATProtoResponse<ComAtprotoSyncGetBlobOutput> {
    val endpoint = "com.atproto.sync.getBlob"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "*/*"),
        body = null
    )
}
