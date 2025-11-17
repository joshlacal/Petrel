// Lexicon: 1, ID: com.atproto.repo.deleteRecord
// Delete a repository record, or ensure it doesn't exist. Requires auth, implemented by PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoRepoDeleterecord {
    const val TYPE_IDENTIFIER = "com.atproto.repo.deleteRecord"

    @Serializable
    data class Input(
// The handle or DID of the repo (aka, current account).        @SerialName("repo")
        val repo: ATIdentifier,// The NSID of the record collection.        @SerialName("collection")
        val collection: NSID,// The Record Key.        @SerialName("rkey")
        val rkey: String,// Compare and swap with the previous record by CID.        @SerialName("swapRecord")
        val swapRecord: CID? = null,// Compare and swap with the previous commit by CID.        @SerialName("swapCommit")
        val swapCommit: CID? = null    )

        @Serializable
    data class Output(
        @SerialName("commit")
        val commit: ComAtprotoRepoDefs.Commitmeta? = null    )

    sealed class Error(val name: String, val description: String?) {
        object Invalidswap: Error("InvalidSwap", "")
    }

}

/**
 * Delete a repository record, or ensure it doesn't exist. Requires auth, implemented by PDS.
 *
 * Endpoint: com.atproto.repo.deleteRecord
 */
suspend fun ATProtoClient.Com.Atproto.Repo.deleterecord(
input: ComAtprotoRepoDeleterecord.Input): ATProtoResponse<ComAtprotoRepoDeleterecord.Output> {
    val endpoint = "com.atproto.repo.deleteRecord"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
