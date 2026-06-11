// Lexicon: 1, ID: app.bsky.embed.getEmbedExternalView
// Resolve one or more AT-URIs into the data needed to render an enhanced external embed. Returns `associatedRefs` (strongRefs to embed into a post's external.associatedRefs), the raw `associatedRecords`, and a hydrated `view`. The response is empty (`{}`) when no records were resolvable, or when validation determined the resolved records don't actually back the requested URL; clients should fall back to their own link-card rendering in that case and skip writing strongRefs to the post.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyEmbedGetEmbedExternalViewDefs {
    const val TYPE_IDENTIFIER = "app.bsky.embed.getEmbedExternalView"
}

@Serializable
    data class AppBskyEmbedGetEmbedExternalViewParameters(
// The canonical web URL the embed represents (typically the URL the user pasted into the composer). Used as the returned view's `uri`. May be used for validation in the future.        @SerialName("url")
        val url: URI,// AT-URIs of any Atmosphere records that can be resolved and used to construct #externalView views. Example: a site.standard.document and optionally its associated site.standard.publication.        @SerialName("uris")
        val uris: List<ATProtocolURI>    )

    @Serializable
    data class AppBskyEmbedGetEmbedExternalViewOutput(
// Hydrated view of the embed. Present only when the resolved records back the requested URL and supply enough information to populate the required `viewExternal` fields. Omitted alongside the rest of the response when no records resolved or validation failed.        @SerialName("view")
        val view: AppBskyEmbedExternalView? = null,// StrongRefs (URI+CID) of the Atmosphere records that backed this view, suitable for embedding into a post's external.associatedRefs.        @SerialName("associatedRefs")
        val associatedRefs: List<ComAtprotoRepoStrongRef>? = null,        @SerialName("associatedRecords")
        val associatedRecords: List<JsonElement>? = null    )

/**
 * Resolve one or more AT-URIs into the data needed to render an enhanced external embed. Returns `associatedRefs` (strongRefs to embed into a post's external.associatedRefs), the raw `associatedRecords`, and a hydrated `view`. The response is empty (`{}`) when no records were resolvable, or when validation determined the resolved records don't actually back the requested URL; clients should fall back to their own link-card rendering in that case and skip writing strongRefs to the post.
 *
 * Endpoint: app.bsky.embed.getEmbedExternalView
 */
suspend fun ATProtoClient.App.Bsky.Embed.getEmbedExternalView(
parameters: AppBskyEmbedGetEmbedExternalViewParameters): ATProtoResponse<AppBskyEmbedGetEmbedExternalViewOutput> {
    val endpoint = "app.bsky.embed.getEmbedExternalView"

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
