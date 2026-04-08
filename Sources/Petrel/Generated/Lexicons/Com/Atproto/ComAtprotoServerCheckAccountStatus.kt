// Lexicon: 1, ID: com.atproto.server.checkAccountStatus
// Returns the status of an account, especially as pertaining to import or recovery. Can be called many times over the course of an account migration. Requires auth and can only be called pertaining to oneself.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerCheckAccountStatusDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.checkAccountStatus"
}

    @Serializable
    data class ComAtprotoServerCheckAccountStatusOutput(
        @SerialName("activated")
        val activated: Boolean,        @SerialName("validDid")
        val validDid: Boolean,        @SerialName("repoCommit")
        val repoCommit: CID,        @SerialName("repoRev")
        val repoRev: String,        @SerialName("repoBlocks")
        val repoBlocks: Int,        @SerialName("indexedRecords")
        val indexedRecords: Int,        @SerialName("privateStateValues")
        val privateStateValues: Int,        @SerialName("expectedBlobs")
        val expectedBlobs: Int,        @SerialName("importedBlobs")
        val importedBlobs: Int    )

/**
 * Returns the status of an account, especially as pertaining to import or recovery. Can be called many times over the course of an account migration. Requires auth and can only be called pertaining to oneself.
 *
 * Endpoint: com.atproto.server.checkAccountStatus
 */
suspend fun ATProtoClient.Com.Atproto.Server.checkAccountStatus(
): ATProtoResponse<ComAtprotoServerCheckAccountStatusOutput> {
    val endpoint = "com.atproto.server.checkAccountStatus"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
