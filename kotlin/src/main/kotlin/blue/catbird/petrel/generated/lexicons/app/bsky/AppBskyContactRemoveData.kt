// Lexicon: 1, ID: app.bsky.contact.removeData
// Removes all stored hashes used for contact matching, existing matches, and sync status. Requires authentication.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyContactRemoveDataDefs {
    const val TYPE_IDENTIFIER = "app.bsky.contact.removeData"
}

@Serializable
    class AppBskyContactRemoveDataInput

    @Serializable
    class AppBskyContactRemoveDataOutput

sealed class AppBskyContactRemoveDataError(val name: String, val description: String?) {
        object InvalidDid: AppBskyContactRemoveDataError("InvalidDid", "")
        object InternalError: AppBskyContactRemoveDataError("InternalError", "")
    }

/**
 * Removes all stored hashes used for contact matching, existing matches, and sync status. Requires authentication.
 *
 * Endpoint: app.bsky.contact.removeData
 */
suspend fun ATProtoClient.App.Bsky.Contact.removeData(
input: AppBskyContactRemoveDataInput): ATProtoResponse<AppBskyContactRemoveDataOutput> {
    val endpoint = "app.bsky.contact.removeData"

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
            "Accept" to "application/json"
        ),
        body = body
    )
}
