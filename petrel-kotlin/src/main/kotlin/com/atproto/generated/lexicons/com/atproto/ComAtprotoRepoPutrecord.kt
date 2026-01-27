// Lexicon: 1, ID: com.atproto.repo.putRecord
// Write a repository record, creating or updating it as needed. Requires auth, implemented by PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoRepoPutRecordDefs {
    const val TYPE_IDENTIFIER = "com.atproto.repo.putRecord"
}

@Serializable
    data class ComAtprotoRepoPutRecordInput(
// The handle or DID of the repo (aka, current account).        @SerialName("repo")
        val repo: ATIdentifier,// The NSID of the record collection.        @SerialName("collection")
        val collection: NSID,// The Record Key.        @SerialName("rkey")
        val rkey: String,// Can be set to 'false' to skip Lexicon schema validation of record data, 'true' to require it, or leave unset to validate only for known Lexicons.        @SerialName("validate")
        val validate: Boolean? = null,// The record to write.        @SerialName("record")
        val record: JsonElement,// Compare and swap with the previous record by CID. WARNING: nullable and optional field; may cause problems with golang implementation        @SerialName("swapRecord")
        val swapRecord: CID? = null,// Compare and swap with the previous commit by CID.        @SerialName("swapCommit")
        val swapCommit: CID? = null    )

    @Serializable
    data class ComAtprotoRepoPutRecordOutput(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("commit")
        val commit: ComAtprotoRepoDefsCommitMeta? = null,        @SerialName("validationStatus")
        val validationStatus: String? = null    )

sealed class ComAtprotoRepoPutRecordError(val name: String, val description: String?) {
        object InvalidSwap: ComAtprotoRepoPutRecordError("InvalidSwap", "")
    }

/**
 * Write a repository record, creating or updating it as needed. Requires auth, implemented by PDS.
 *
 * Endpoint: com.atproto.repo.putRecord
 */
suspend fun ATProtoClient.Com.Atproto.Repo.putRecord(
input: ComAtprotoRepoPutRecordInput): ATProtoResponse<ComAtprotoRepoPutRecordOutput> {
    val endpoint = "com.atproto.repo.putRecord"

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
