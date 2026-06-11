// Lexicon: 1, ID: app.bsky.contact.getSyncStatus
// Gets the user's current contact import status. Requires authentication.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyContactGetSyncStatusDefs {
    const val TYPE_IDENTIFIER = "app.bsky.contact.getSyncStatus"
}

@Serializable
    class AppBskyContactGetSyncStatusParameters

    @Serializable
    data class AppBskyContactGetSyncStatusOutput(
// If present, indicates the user has imported their contacts. If not present, indicates the user never used the feature or called `app.bsky.contact.removeData` and didn't import again since.        @SerialName("syncStatus")
        val syncStatus: AppBskyContactDefsSyncStatus? = null    )

sealed class AppBskyContactGetSyncStatusError(val name: String, val description: String?) {
        object InvalidDid: AppBskyContactGetSyncStatusError("InvalidDid", "")
        object InternalError: AppBskyContactGetSyncStatusError("InternalError", "")
    }

/**
 * Gets the user's current contact import status. Requires authentication.
 *
 * Endpoint: app.bsky.contact.getSyncStatus
 */
suspend fun ATProtoClient.App.Bsky.Contact.getSyncStatus(
parameters: AppBskyContactGetSyncStatusParameters): ATProtoResponse<AppBskyContactGetSyncStatusOutput> {
    val endpoint = "app.bsky.contact.getSyncStatus"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
