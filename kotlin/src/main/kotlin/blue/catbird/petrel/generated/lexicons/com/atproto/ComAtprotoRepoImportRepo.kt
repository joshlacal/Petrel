// Lexicon: 1, ID: com.atproto.repo.importRepo
// Import a repo in the form of a CAR file. Requires Content-Length HTTP header to be set.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
