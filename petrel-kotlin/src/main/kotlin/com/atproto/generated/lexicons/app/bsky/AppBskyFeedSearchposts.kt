// Lexicon: 1, ID: app.bsky.feed.searchPosts
// Find posts matching search criteria, returning views of those posts. Note that this API endpoint may require authentication (eg, not public) for some service providers and implementations.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedSearchPostsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.searchPosts"
}

@Serializable
    data class AppBskyFeedSearchPostsParameters(
// Search query string; syntax, phrase, boolean, and faceting is unspecified, but Lucene query syntax is recommended.        @SerialName("q")
        val q: String,// Specifies the ranking order of results.        @SerialName("sort")
        val sort: String? = null,// Filter results for posts after the indicated datetime (inclusive). Expected to use 'sortAt' timestamp, which may not match 'createdAt'. Can be a datetime, or just an ISO date (YYYY-MM-DD).        @SerialName("since")
        val since: String? = null,// Filter results for posts before the indicated datetime (not inclusive). Expected to use 'sortAt' timestamp, which may not match 'createdAt'. Can be a datetime, or just an ISO date (YYY-MM-DD).        @SerialName("until")
        val until: String? = null,// Filter to posts which mention the given account. Handles are resolved to DID before query-time. Only matches rich-text facet mentions.        @SerialName("mentions")
        val mentions: ATIdentifier? = null,// Filter to posts by the given account. Handles are resolved to DID before query-time.        @SerialName("author")
        val author: ATIdentifier? = null,// Filter to posts in the given language. Expected to be based on post language field, though server may override language detection.        @SerialName("lang")
        val lang: Language? = null,// Filter to posts with URLs (facet links or embeds) linking to the given domain (hostname). Server may apply hostname normalization.        @SerialName("domain")
        val domain: String? = null,// Filter to posts with links (facet links or embeds) pointing to this URL. Server may apply URL normalization or fuzzy matching.        @SerialName("url")
        val url: URI? = null,// Filter to posts with the given tag (hashtag), based on rich-text facet or tag field. Do not include the hash (#) prefix. Multiple tags can be specified, with 'AND' matching.        @SerialName("tag")
        val tag: List<String>? = null,        @SerialName("limit")
        val limit: Int? = null,// Optional pagination mechanism; may not necessarily allow scrolling through entire result set.        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyFeedSearchPostsOutput(
        @SerialName("cursor")
        val cursor: String? = null,// Count of search hits. Optional, may be rounded/truncated, and may not be possible to paginate through all hits.        @SerialName("hitsTotal")
        val hitsTotal: Int? = null,        @SerialName("posts")
        val posts: List<AppBskyFeedDefsPostView>    )

sealed class AppBskyFeedSearchPostsError(val name: String, val description: String?) {
        object BadQueryString: AppBskyFeedSearchPostsError("BadQueryString", "")
    }

/**
 * Find posts matching search criteria, returning views of those posts. Note that this API endpoint may require authentication (eg, not public) for some service providers and implementations.
 *
 * Endpoint: app.bsky.feed.searchPosts
 */
suspend fun ATProtoClient.App.Bsky.Feed.searchPosts(
parameters: AppBskyFeedSearchPostsParameters): ATProtoResponse<AppBskyFeedSearchPostsOutput> {
    val endpoint = "app.bsky.feed.searchPosts"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
