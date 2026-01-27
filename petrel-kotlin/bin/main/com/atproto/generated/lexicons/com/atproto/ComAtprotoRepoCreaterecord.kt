// Lexicon: 1, ID: com.atproto.repo.createRecord
// Create a single new repository record. Requires auth, implemented by PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoRepoCreateRecordDefs {
    const val TYPE_IDENTIFIER = "com.atproto.repo.createRecord"
}

@Serializable
    data class ComAtprotoRepoCreateRecordInput(
// The handle or DID of the repo (aka, current account).        @SerialName("repo")
        val repo: ATIdentifier,// The NSID of the record collection.        @SerialName("collection")
        val collection: NSID,// The Record Key.        @SerialName("rkey")
        val rkey: String? = null,// Can be set to 'false' to skip Lexicon schema validation of record data, 'true' to require it, or leave unset to validate only for known Lexicons.        @SerialName("validate")
        val validate: Boolean? = null,// The record itself. Must contain a $type field.        @SerialName("record")
        val record: JsonElement,// Compare and swap with the previous commit by CID.        @SerialName("swapCommit")
        val swapCommit: CID? = null    )

    @Serializable
    data class ComAtprotoRepoCreateRecordOutput(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("commit")
        val commit: ComAtprotoRepoDefsCommitMeta? = null,        @SerialName("validationStatus")
        val validationStatus: String? = null    )

sealed class ComAtprotoRepoCreateRecordError(val name: String, val description: String?) {
        object InvalidSwap: ComAtprotoRepoCreateRecordError("InvalidSwap", "Indicates that 'swapCommit' didn't match current repo commit.")
    }

/**
 * Create a single new repository record. Requires auth, implemented by PDS.
 *
 * Endpoint: com.atproto.repo.createRecord
 */
suspend fun ATProtoClient.Com.Atproto.Repo.createRecord(
input: ComAtprotoRepoCreateRecordInput): ATProtoResponse<ComAtprotoRepoCreateRecordOutput> {
    val endpoint = "com.atproto.repo.createRecord"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
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
