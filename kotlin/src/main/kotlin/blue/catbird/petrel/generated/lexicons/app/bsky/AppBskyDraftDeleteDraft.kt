// Lexicon: 1, ID: app.bsky.draft.deleteDraft
// Deletes a draft by ID. Requires authentication.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyDraftDeleteDraftDefs {
    const val TYPE_IDENTIFIER = "app.bsky.draft.deleteDraft"
}

@Serializable
    data class AppBskyDraftDeleteDraftInput(
        @SerialName("id")
        val id: String    )

/**
 * Deletes a draft by ID. Requires authentication.
 *
 * Endpoint: app.bsky.draft.deleteDraft
 */
suspend fun ATProtoClient.App.Bsky.Draft.deleteDraft(
input: AppBskyDraftDeleteDraftInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.draft.deleteDraft"

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
