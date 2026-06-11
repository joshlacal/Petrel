// Lexicon: 1, ID: app.bsky.draft.createDraft
// Inserts a draft using private storage (stash). An upper limit of drafts might be enforced. Requires authentication.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyDraftCreateDraftDefs {
    const val TYPE_IDENTIFIER = "app.bsky.draft.createDraft"
}

@Serializable
    data class AppBskyDraftCreateDraftInput(
        @SerialName("draft")
        val draft: AppBskyDraftDefsDraft    )

    @Serializable
    data class AppBskyDraftCreateDraftOutput(
// The ID of the created draft.        @SerialName("id")
        val id: String    )

sealed class AppBskyDraftCreateDraftError(val name: String, val description: String?) {
        object DraftLimitReached: AppBskyDraftCreateDraftError("DraftLimitReached", "Trying to insert a new draft when the limit was already reached.")
    }

/**
 * Inserts a draft using private storage (stash). An upper limit of drafts might be enforced. Requires authentication.
 *
 * Endpoint: app.bsky.draft.createDraft
 */
suspend fun ATProtoClient.App.Bsky.Draft.createDraft(
input: AppBskyDraftCreateDraftInput): ATProtoResponse<AppBskyDraftCreateDraftOutput> {
    val endpoint = "app.bsky.draft.createDraft"

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
