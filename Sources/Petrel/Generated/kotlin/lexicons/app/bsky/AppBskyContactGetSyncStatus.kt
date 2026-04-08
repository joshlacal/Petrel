// Lexicon: 1, ID: app.bsky.contact.getSyncStatus
// Gets the user's current contact import status. Requires authentication.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
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

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
