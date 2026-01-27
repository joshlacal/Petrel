// Lexicon: 1, ID: app.bsky.graph.list
// Record representing a list of accounts (actors). Scope includes both moderation-oriented lists and curration-oriented lists.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphListDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.list"
}

@Serializable
sealed interface AppBskyGraphListLabelsUnion {
    @Serializable
    @SerialName("app.bsky.graph.list#ComAtprotoLabelDefsSelfLabels")
    data class ComAtprotoLabelDefsSelfLabels(val value: ComAtprotoLabelDefsSelfLabels) : AppBskyGraphListLabelsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyGraphListLabelsUnion
}

    /**
     * Record representing a list of accounts (actors). Scope includes both moderation-oriented lists and curration-oriented lists.
     */
    @Serializable
    data class AppBskyGraphList(
/** Defines the purpose of the list (aka, moderation-oriented or curration-oriented) */        @SerialName("purpose")
        val purpose: AppBskyGraphDefsListPurpose,/** Display name for list; can not be empty. */        @SerialName("name")
        val name: String,        @SerialName("description")
        val description: String? = null,        @SerialName("descriptionFacets")
        val descriptionFacets: List<AppBskyRichtextFacet>? = null,        @SerialName("avatar")
        val avatar: Blob? = null,        @SerialName("labels")
        val labels: AppBskyGraphListLabelsUnion? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
