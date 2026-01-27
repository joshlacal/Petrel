// Lexicon: 1, ID: com.atproto.repo.importRepo
// Import a repo in the form of a CAR file. Requires Content-Length HTTP header to be set.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoRepoImportRepoDefs {
    const val TYPE_IDENTIFIER = "com.atproto.repo.importRepo"
}

@Serializable
    data class ComAtprotoRepoImportRepoInput(
        @SerialName("data")
        val `data`: ByteArray    )

/**
 * Import a repo in the form of a CAR file. Requires Content-Length HTTP header to be set.
 *
 * Endpoint: com.atproto.repo.importRepo
 */
suspend fun ATProtoClient.Com.Atproto.Repo.importRepo(
input: ComAtprotoRepoImportRepoInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.repo.importRepo"

    // Binary data
    val body = input.data
    val contentType = "application/vnd.ipld.car"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
