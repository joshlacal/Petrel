// Lexicon: 1, ID: app.bsky.graph.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphDefsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.defs"
}

@Serializable
enum class AppBskyGraphDefsListPurpose {
    @SerialName("app.bsky.graph.defs#modlist")
    APP_BSKY_GRAPH_DEFS_MODLIST,
    @SerialName("app.bsky.graph.defs#curatelist")
    APP_BSKY_GRAPH_DEFS_CURATELIST,
    @SerialName("app.bsky.graph.defs#referencelist")
    APP_BSKY_GRAPH_DEFS_REFERENCELIST}

    @Serializable
    data class AppBskyGraphDefsListViewBasic(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("name")
        val name: String,        @SerialName("purpose")
        val purpose: AppBskyGraphDefsListPurpose,        @SerialName("avatar")
        val avatar: URI?,        @SerialName("listItemCount")
        val listItemCount: Int?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>?,        @SerialName("viewer")
        val viewer: AppBskyGraphDefsListViewerState?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyGraphDefsListViewBasic"
        }
    }

    @Serializable
    data class AppBskyGraphDefsListView(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("creator")
        val creator: AppBskyActorDefsProfileView,        @SerialName("name")
        val name: String,        @SerialName("purpose")
        val purpose: AppBskyGraphDefsListPurpose,        @SerialName("description")
        val description: String?,        @SerialName("descriptionFacets")
        val descriptionFacets: List<AppBskyRichtextFacet>?,        @SerialName("avatar")
        val avatar: URI?,        @SerialName("listItemCount")
        val listItemCount: Int?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>?,        @SerialName("viewer")
        val viewer: AppBskyGraphDefsListViewerState?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyGraphDefsListView"
        }
    }

    @Serializable
    data class AppBskyGraphDefsListItemView(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("subject")
        val subject: AppBskyActorDefsProfileView    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyGraphDefsListItemView"
        }
    }

    @Serializable
    data class AppBskyGraphDefsStarterPackView(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("record")
        val record: JsonElement,        @SerialName("creator")
        val creator: AppBskyActorDefsProfileViewBasic,        @SerialName("list")
        val list: AppBskyGraphDefsListViewBasic?,        @SerialName("listItemsSample")
        val listItemsSample: List<AppBskyGraphDefsListItemView>?,        @SerialName("feeds")
        val feeds: List<AppBskyFeedDefsGeneratorView>?,        @SerialName("joinedWeekCount")
        val joinedWeekCount: Int?,        @SerialName("joinedAllTimeCount")
        val joinedAllTimeCount: Int?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyGraphDefsStarterPackView"
        }
    }

    @Serializable
    data class AppBskyGraphDefsStarterPackViewBasic(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("record")
        val record: JsonElement,        @SerialName("creator")
        val creator: AppBskyActorDefsProfileViewBasic,        @SerialName("listItemCount")
        val listItemCount: Int?,        @SerialName("joinedWeekCount")
        val joinedWeekCount: Int?,        @SerialName("joinedAllTimeCount")
        val joinedAllTimeCount: Int?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyGraphDefsStarterPackViewBasic"
        }
    }

    @Serializable
    data class AppBskyGraphDefsListViewerState(
        @SerialName("muted")
        val muted: Boolean?,        @SerialName("blocked")
        val blocked: ATProtocolURI?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyGraphDefsListViewerState"
        }
    }

    /**
     * indicates that a handle or DID could not be resolved
     */
    @Serializable
    data class AppBskyGraphDefsNotFoundActor(
        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("notFound")
        val notFound: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyGraphDefsNotFoundActor"
        }
    }

    /**
     * lists the bi-directional graph relationships between one actor (not indicated in the object), and the target actors (the DID included in the object)
     */
    @Serializable
    data class AppBskyGraphDefsRelationship(
        @SerialName("did")
        val did: DID,/** if the actor follows this DID, this is the AT-URI of the follow record */        @SerialName("following")
        val following: ATProtocolURI?,/** if the actor is followed by this DID, contains the AT-URI of the follow record */        @SerialName("followedBy")
        val followedBy: ATProtocolURI?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyGraphDefsRelationship"
        }
    }
