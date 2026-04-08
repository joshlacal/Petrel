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
        val avatar: URI? = null,        @SerialName("listItemCount")
        val listItemCount: Int? = null,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>? = null,        @SerialName("viewer")
        val viewer: AppBskyGraphDefsListViewerState? = null,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate? = null    ) {
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
        val description: String? = null,        @SerialName("descriptionFacets")
        val descriptionFacets: List<AppBskyRichtextFacet>? = null,        @SerialName("avatar")
        val avatar: URI? = null,        @SerialName("listItemCount")
        val listItemCount: Int? = null,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>? = null,        @SerialName("viewer")
        val viewer: AppBskyGraphDefsListViewerState? = null,        @SerialName("indexedAt")
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
        val list: AppBskyGraphDefsListViewBasic? = null,        @SerialName("listItemsSample")
        val listItemsSample: List<AppBskyGraphDefsListItemView>? = null,        @SerialName("feeds")
        val feeds: List<AppBskyFeedDefsGeneratorView>? = null,        @SerialName("joinedWeekCount")
        val joinedWeekCount: Int? = null,        @SerialName("joinedAllTimeCount")
        val joinedAllTimeCount: Int? = null,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>? = null,        @SerialName("indexedAt")
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
        val listItemCount: Int? = null,        @SerialName("joinedWeekCount")
        val joinedWeekCount: Int? = null,        @SerialName("joinedAllTimeCount")
        val joinedAllTimeCount: Int? = null,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>? = null,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyGraphDefsStarterPackViewBasic"
        }
    }

    @Serializable
    data class AppBskyGraphDefsListViewerState(
        @SerialName("muted")
        val muted: Boolean? = null,        @SerialName("blocked")
        val blocked: ATProtocolURI? = null    ) {
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
        val following: ATProtocolURI? = null,/** if the actor is followed by this DID, contains the AT-URI of the follow record */        @SerialName("followedBy")
        val followedBy: ATProtocolURI? = null,/** if the actor blocks this DID, this is the AT-URI of the block record */        @SerialName("blocking")
        val blocking: ATProtocolURI? = null,/** if the actor is blocked by this DID, contains the AT-URI of the block record */        @SerialName("blockedBy")
        val blockedBy: ATProtocolURI? = null,/** if the actor blocks this DID via a block list, this is the AT-URI of the listblock record */        @SerialName("blockingByList")
        val blockingByList: ATProtocolURI? = null,/** if the actor is blocked by this DID via a block list, contains the AT-URI of the listblock record */        @SerialName("blockedByList")
        val blockedByList: ATProtocolURI? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyGraphDefsRelationship"
        }
    }
