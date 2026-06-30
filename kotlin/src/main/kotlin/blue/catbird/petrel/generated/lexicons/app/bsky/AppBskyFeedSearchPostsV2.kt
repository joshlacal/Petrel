// Lexicon: 1, ID: app.bsky.feed.searchPostsV2
// Find posts matching a search query or filters, returning search hits for matching post records.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyFeedSearchPostsV2Defs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.searchPostsV2"
}

@Serializable
    data class AppBskyFeedSearchPostsV2Parameters(
// Optional pagination cursor.        @SerialName("cursor")
        val cursor: String? = null,// Maximum number of results to return.        @SerialName("limit")
        val limit: Int? = null,// Search query string. A query or at least one filter is required.        @SerialName("query")
        val query: String? = null,// Ranking order for results. 'recent' sorts by recency; 'top' uses search ranking.        @SerialName("sort")
        val sort: String? = null,// Include posts by any of these authors. Handles are resolved to DIDs before searching.        @SerialName("authors")
        val authors: List<ATIdentifier>? = null,// Include posts that mention any of these accounts. Handles are resolved to DIDs before searching.        @SerialName("mentions")
        val mentions: List<ATIdentifier>? = null,// Include posts that link to any of these domains.        @SerialName("domains")
        val domains: List<String>? = null,// Include posts that link to any of these URLs.        @SerialName("urls")
        val urls: List<URI>? = null,// Include posts that embed any of these AT URIs.        @SerialName("embeddedAtUris")
        val embeddedAtUris: List<ATProtocolURI>? = null,// Include posts tagged with any of these hashtags. Do not include the hash (#) prefix.        @SerialName("hashtags")
        val hashtags: List<String>? = null,// Exclude posts by any of these authors. Handles are resolved to DIDs before searching.        @SerialName("excludeAuthors")
        val excludeAuthors: List<ATIdentifier>? = null,// Exclude posts that mention any of these accounts. Handles are resolved to DIDs before searching.        @SerialName("excludeMentions")
        val excludeMentions: List<ATIdentifier>? = null,// Exclude posts that link to any of these domains.        @SerialName("excludeDomains")
        val excludeDomains: List<String>? = null,// Exclude posts that link to any of these URLs.        @SerialName("excludeUrls")
        val excludeUrls: List<URI>? = null,// Exclude posts that embed any of these AT URIs.        @SerialName("excludeEmbeddedAtUris")
        val excludeEmbeddedAtUris: List<ATProtocolURI>? = null,// Exclude posts tagged with any of these hashtags. Do not include the hash (#) prefix.        @SerialName("excludeHashtags")
        val excludeHashtags: List<String>? = null,// Include posts indexed at or after this timestamp. Can be a datetime, or just an ISO date (YYYY-MM-DD).        @SerialName("since")
        val since: String? = null,// Include posts indexed before this timestamp. Defaults to the current time. Can be a datetime, or just an ISO date (YYYY-MM-DD).        @SerialName("until")
        val until: String? = null,// Search the full index instead of the recent-post window.        @SerialName("allTime")
        val allTime: Boolean? = null,// Include posts whose language matches any of these language codes.        @SerialName("languages")
        val languages: List<Language>? = null,// Exclude posts whose language matches any of these language codes.        @SerialName("excludeLanguages")
        val excludeLanguages: List<Language>? = null,// Include only posts with media.        @SerialName("hasMedia")
        val hasMedia: Boolean? = null,// Include only posts with video.        @SerialName("hasVideo")
        val hasVideo: Boolean? = null,// Include only direct replies to this parent post URI.        @SerialName("replyParentUri")
        val replyParentUri: ATProtocolURI? = null,// Include only posts in the thread rooted at this post URI.        @SerialName("threadRootUri")
        val threadRootUri: ATProtocolURI? = null,// Exclude replies from results. Mutually exclusive with repliesOnly.        @SerialName("excludeReplies")
        val excludeReplies: Boolean? = null,// Include only replies. Mutually exclusive with excludeReplies.        @SerialName("repliesOnly")
        val repliesOnly: Boolean? = null,// Include only posts from accounts followed by the viewer.        @SerialName("following")
        val following: Boolean? = null,// Language analyzer hint for the query text. If unset, the server auto-detects when possible.        @SerialName("queryLanguage")
        val queryLanguage: String? = null    )

    @Serializable
    data class AppBskyFeedSearchPostsV2Output(
// Cursor for the next page of results.        @SerialName("cursor")
        val cursor: String? = null,// Estimated total number of matching hits. May be rounded or truncated.        @SerialName("hitsTotal")
        val hitsTotal: Int? = null,// Hydrated views of matching posts.        @SerialName("posts")
        val posts: List<AppBskyFeedDefsPostView>,// Query languages detected for CJK, Thai, or Arabic text. Empty or omitted for other scripts.        @SerialName("detectedQueryLanguages")
        val detectedQueryLanguages: List<String>? = null    )

sealed class AppBskyFeedSearchPostsV2Error(val name: String, val description: String?) {
        object BadQueryString: AppBskyFeedSearchPostsV2Error("BadQueryString", "")
    }

/**
 * Find posts matching a search query or filters, returning search hits for matching post records.
 *
 * Endpoint: app.bsky.feed.searchPostsV2
 */
suspend fun ATProtoClient.App.Bsky.Feed.searchPostsV2(
parameters: AppBskyFeedSearchPostsV2Parameters): ATProtoResponse<AppBskyFeedSearchPostsV2Output> {
    val endpoint = "app.bsky.feed.searchPostsV2"

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
