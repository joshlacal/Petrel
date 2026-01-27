// Lexicon: 1, ID: app.bsky.feed.generator
// Record declaring of the existence of a feed generator, and containing metadata about it. The record can exist in any repository.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedGeneratorDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.generator"
}

@Serializable
sealed interface AppBskyFeedGeneratorLabelsUnion {
    @Serializable
    @SerialName("app.bsky.feed.generator#ComAtprotoLabelDefsSelfLabels")
    data class ComAtprotoLabelDefsSelfLabels(val value: ComAtprotoLabelDefsSelfLabels) : AppBskyFeedGeneratorLabelsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyFeedGeneratorLabelsUnion
}

    /**
     * Record declaring of the existence of a feed generator, and containing metadata about it. The record can exist in any repository.
     */
    @Serializable
    data class AppBskyFeedGenerator(
        @SerialName("did")
        val did: DID,        @SerialName("displayName")
        val displayName: String,        @SerialName("description")
        val description: String? = null,        @SerialName("descriptionFacets")
        val descriptionFacets: List<AppBskyRichtextFacet>? = null,        @SerialName("avatar")
        val avatar: Blob? = null,/** Declaration that a feed accepts feedback interactions from a client through app.bsky.feed.sendInteractions */        @SerialName("acceptsInteractions")
        val acceptsInteractions: Boolean? = null,/** Self-label values */        @SerialName("labels")
        val labels: AppBskyFeedGeneratorLabelsUnion? = null,        @SerialName("contentMode")
        val contentMode: String? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
