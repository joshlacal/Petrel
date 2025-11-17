// Lexicon: 1, ID: com.atproto.repo.uploadBlob
// Upload a new blob, to be referenced from a repository record. The blob will be deleted if it is not referenced within a time window (eg, minutes). Blob restrictions (mimetype, size, etc) are enforced when the reference is created. Requires auth, implemented by PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoRepoUploadblob {
    const val TYPE_IDENTIFIER = "com.atproto.repo.uploadBlob"

    @Serializable
    data class Input(
        @SerialName("data")
        val `data`: ByteArray    )

        @Serializable
    data class Output(
        @SerialName("blob")
        val blob: Blob    )

}

/**
 * Upload a new blob, to be referenced from a repository record. The blob will be deleted if it is not referenced within a time window (eg, minutes). Blob restrictions (mimetype, size, etc) are enforced when the reference is created. Requires auth, implemented by PDS.
 *
 * Endpoint: com.atproto.repo.uploadBlob
 */
suspend fun ATProtoClient.Com.Atproto.Repo.uploadblob(
input: ComAtprotoRepoUploadblob.Input): ATProtoResponse<ComAtprotoRepoUploadblob.Output> {
    val endpoint = "com.atproto.repo.uploadBlob"

    // Blob upload - input.data is ByteArray
    val body = input.data
    val contentType = "*/*"

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
