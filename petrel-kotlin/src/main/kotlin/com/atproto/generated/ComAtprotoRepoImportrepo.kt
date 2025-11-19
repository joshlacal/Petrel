// Lexicon: 1, ID: com.atproto.repo.importRepo
// Import a repo in the form of a CAR file. Requires Content-Length HTTP header to be set.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoRepoImportrepo {
    const val TYPE_IDENTIFIER = "com.atproto.repo.importRepo"

    @Serializable
    data class Input(
        @SerialName("data")
        val `data`: ByteArray    )

}

/**
 * Import a repo in the form of a CAR file. Requires Content-Length HTTP header to be set.
 *
 * Endpoint: com.atproto.repo.importRepo
 */
suspend fun ATProtoClient.Com.Atproto.Repo.importrepo(
input: ComAtprotoRepoImportrepo.Input): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.repo.importRepo"

    // Binary data
    val body = input.data
    val contentType = "application/vnd.ipld.car"

    return networkService.performRequest(
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
