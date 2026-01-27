// Lexicon: 1, ID: app.bsky.unspecced.searchPostsSkeleton
// Backend Posts search, returns only skeleton
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedSearchPostsSkeletonDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.searchPostsSkeleton"
}

@Serializable
    data class AppBskyUnspeccedSearchPostsSkeletonParameters(
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
        val tag: List<String>? = null,// DID of the account making the request (not included for public/unauthenticated queries). Used for 'from:me' queries.        @SerialName("viewer")
        val viewer: DID? = null,        @SerialName("limit")
        val limit: Int? = null,// Optional pagination mechanism; may not necessarily allow scrolling through entire result set.        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyUnspeccedSearchPostsSkeletonOutput(
        @SerialName("cursor")
        val cursor: String? = null,// Count of search hits. Optional, may be rounded/truncated, and may not be possible to paginate through all hits.        @SerialName("hitsTotal")
        val hitsTotal: Int? = null,        @SerialName("posts")
        val posts: List<AppBskyUnspeccedDefsSkeletonSearchPost>    )

sealed class AppBskyUnspeccedSearchPostsSkeletonError(val name: String, val description: String?) {
        object BadQueryString: AppBskyUnspeccedSearchPostsSkeletonError("BadQueryString", "")
    }

/**
 * Backend Posts search, returns only skeleton
 *
 * Endpoint: app.bsky.unspecced.searchPostsSkeleton
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.searchPostsSkeleton(
parameters: AppBskyUnspeccedSearchPostsSkeletonParameters): ATProtoResponse<AppBskyUnspeccedSearchPostsSkeletonOutput> {
    val endpoint = "app.bsky.unspecced.searchPostsSkeleton"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
