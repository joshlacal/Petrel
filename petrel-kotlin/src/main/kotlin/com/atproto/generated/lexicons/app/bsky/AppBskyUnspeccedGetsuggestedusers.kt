// Lexicon: 1, ID: app.bsky.unspecced.getSuggestedUsers
// Get a list of suggested users
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetSuggestedUsersDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestedUsers"
}

@Serializable
    data class AppBskyUnspeccedGetSuggestedUsersParameters(
// Category of users to get suggestions for.        @SerialName("category")
        val category: String? = null,        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyUnspeccedGetSuggestedUsersOutput(
        @SerialName("actors")
        val actors: List<AppBskyActorDefsProfileView>    )

/**
 * Get a list of suggested users
 *
 * Endpoint: app.bsky.unspecced.getSuggestedUsers
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getSuggestedUsers(
parameters: AppBskyUnspeccedGetSuggestedUsersParameters): ATProtoResponse<AppBskyUnspeccedGetSuggestedUsersOutput> {
    val endpoint = "app.bsky.unspecced.getSuggestedUsers"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
