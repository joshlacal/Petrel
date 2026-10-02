// Lexicon: 1, ID: com.atproto.space.notifyWrite
// Notify that a repo in a space has advanced. Repo hosts reliably deliver their latest state to the space host, which sequences updates and forwards them to registered syncers with reasonable-effort delivery. Authenticated with service auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSpaceNotifyWriteDefs {
    const val TYPE_IDENTIFIER = "com.atproto.space.notifyWrite"
}

@Serializable
    data class ComAtprotoSpaceNotifyWriteInput(
// Reference to the space.        @SerialName("space")
        val space: SpaceRef,// The DID of the account whose repo advanced.        @SerialName("repo")
        val repo: DID,// The repo revision after the write.        @SerialName("repoRev")
        val repoRev: String,// The repo's current commit hash (sha256 of the LtHash state) after the write. Lets the space host maintain each repo's hash for listRepos.        @SerialName("hash")
        val hash: Bytes,// The space revision assigned by the space host. Present only on notifications forwarded to syncers.        @SerialName("spaceRev")
        val spaceRev: String? = null,// The previous space revision. Omitted on the first update in a space. A gap indicates missed notifications; recover using listRepos with cursor.        @SerialName("prevSpaceRev")
        val prevSpaceRev: String? = null    )

sealed class ComAtprotoSpaceNotifyWriteError(val name: String, val description: String?) {
        object SpaceNotFound: ComAtprotoSpaceNotifyWriteError("SpaceNotFound", "")
        object FutureRev: ComAtprotoSpaceNotifyWriteError("FutureRev", "The repo revision exceeds the permitted clock skew.")
    }

/**
 * Notify that a repo in a space has advanced. Repo hosts reliably deliver their latest state to the space host, which sequences updates and forwards them to registered syncers with reasonable-effort delivery. Authenticated with service auth.
 *
 * Endpoint: com.atproto.space.notifyWrite
 */
suspend fun ATProtoClient.Com.Atproto.Space.notifyWrite(
input: ComAtprotoSpaceNotifyWriteInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.space.notifyWrite"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

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
