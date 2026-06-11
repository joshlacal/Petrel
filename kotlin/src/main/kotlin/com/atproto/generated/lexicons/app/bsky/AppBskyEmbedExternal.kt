// Lexicon: 1, ID: app.bsky.embed.external
// A representation of some externally linked content (eg, a URL and 'card'), embedded in a Bluesky record (eg, a post).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyEmbedExternalDefs {
    const val TYPE_IDENTIFIER = "app.bsky.embed.external"
}

    @Serializable
    data class AppBskyEmbedExternalExternal(
        @SerialName("uri")
        val uri: URI,        @SerialName("title")
        val title: String,        @SerialName("description")
        val description: String,        @SerialName("thumb")
        val thumb: Blob? = null,/** StrongRefs (uri+cid) of the Atmosphere records that backed this view. */        @SerialName("associatedRefs")
        val associatedRefs: List<ComAtprotoRepoStrongRef>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedExternalExternal"
        }
    }

    @Serializable
    data class AppBskyEmbedExternalView(
        @SerialName("external")
        val external: AppBskyEmbedExternalViewExternal    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedExternalView"
        }
    }

    @Serializable
    data class AppBskyEmbedExternalViewExternal(
        @SerialName("uri")
        val uri: URI,        @SerialName("title")
        val title: String,        @SerialName("description")
        val description: String,        @SerialName("thumb")
        val thumb: URI? = null,/** When the external content was created, if available. Example: a publication date, for an article. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate? = null,/** When the external content was updated, if available. */        @SerialName("updatedAt")
        val updatedAt: ATProtocolDate? = null,/** Estimated reading time in minutes, if applicable and available. */        @SerialName("readingTime")
        val readingTime: Int? = null,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>? = null,        @SerialName("source")
        val source: AppBskyEmbedExternalViewExternalSource? = null,/** StrongRefs (uri+cid) of the Atmosphere records that backed this view. */        @SerialName("associatedRefs")
        val associatedRefs: List<ComAtprotoRepoStrongRef>? = null,/** Profiles of the owners of the Atmosphere records that backed this view. */        @SerialName("associatedProfiles")
        val associatedProfiles: List<AppBskyActorDefsProfileViewBasic>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedExternalViewExternal"
        }
    }

    /**
     * The source of an external embed, such as a standard.site publication.
     */
    @Serializable
    data class AppBskyEmbedExternalViewExternalSource(
/** URI of the source, if available. Example: the https:// URL of a site.standard.publication record. */        @SerialName("uri")
        val uri: URI,/** Fully-qualified URL where an icon representing the source can be fetched. For example, CDN location provided by the App View. */        @SerialName("icon")
        val icon: URI? = null,        @SerialName("title")
        val title: String,        @SerialName("description")
        val description: String? = null,        @SerialName("theme")
        val theme: AppBskyEmbedExternalViewExternalSourceTheme? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedExternalViewExternalSource"
        }
    }

    /**
     * The theme colors of an external source, such as a site.standard.publication. These colors may be used when rendering an embed from that source.
     */
    @Serializable
    data class AppBskyEmbedExternalViewExternalSourceTheme(
        @SerialName("backgroundRGB")
        val backgroundRGB: AppBskyEmbedExternalColorRGB? = null,        @SerialName("foregroundRGB")
        val foregroundRGB: AppBskyEmbedExternalColorRGB? = null,        @SerialName("accentRGB")
        val accentRGB: AppBskyEmbedExternalColorRGB? = null,        @SerialName("accentForegroundRGB")
        val accentForegroundRGB: AppBskyEmbedExternalColorRGB? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedExternalViewExternalSourceTheme"
        }
    }

    /**
     * RGB color definition, inspired by site.standard.theme.color#rgb
     */
    @Serializable
    data class AppBskyEmbedExternalColorRGB(
        @SerialName("r")
        val r: Int,        @SerialName("g")
        val g: Int,        @SerialName("b")
        val b: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedExternalColorRGB"
        }
    }

@Serializable
data class AppBskyEmbedExternal(
    @SerialName("external")
    val external: AppBskyEmbedExternalExternal)
