// Lexicon: 1, ID: app.bsky.draft.getDrafts
// Gets views of user drafts. Requires authentication.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyDraftGetDraftsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.draft.getDrafts"
}

@Serializable
    data class AppBskyDraftGetDraftsParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyDraftGetDraftsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("drafts")
        val drafts: List<AppBskyDraftDefsDraftView>    )

/**
 * Gets views of user drafts. Requires authentication.
 *
 * Endpoint: app.bsky.draft.getDrafts
 */
suspend fun ATProtoClient.App.Bsky.Draft.getDrafts(
parameters: AppBskyDraftGetDraftsParameters): ATProtoResponse<AppBskyDraftGetDraftsOutput> {
    val endpoint = "app.bsky.draft.getDrafts"

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
