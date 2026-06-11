// Lexicon: 1, ID: app.bsky.unspecced.getSuggestedOnboardingUsers
// Get a list of suggested users for onboarding
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetSuggestedOnboardingUsersDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestedOnboardingUsers"
}

@Serializable
    data class AppBskyUnspeccedGetSuggestedOnboardingUsersParameters(
// Category of users to get suggestions for.        @SerialName("category")
        val category: String? = null,        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyUnspeccedGetSuggestedOnboardingUsersOutput(
        @SerialName("actors")
        val actors: List<AppBskyActorDefsProfileView>,// DEPRECATED: use recIdStr instead.        @SerialName("recId")
        val recId: String? = null,// Snowflake for this recommendation, use when submitting recommendation events.        @SerialName("recIdStr")
        val recIdStr: String? = null    )

/**
 * Get a list of suggested users for onboarding
 *
 * Endpoint: app.bsky.unspecced.getSuggestedOnboardingUsers
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getSuggestedOnboardingUsers(
parameters: AppBskyUnspeccedGetSuggestedOnboardingUsersParameters): ATProtoResponse<AppBskyUnspeccedGetSuggestedOnboardingUsersOutput> {
    val endpoint = "app.bsky.unspecced.getSuggestedOnboardingUsers"

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
