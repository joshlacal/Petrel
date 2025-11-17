// Lexicon: 1, ID: app.bsky.graph.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
enum class Listpurpose {
    @SerialName("app.bsky.graph.defs#modlist")
    APP_BSKY_GRAPH_DEFS#MODLIST,    @SerialName("app.bsky.graph.defs#curatelist")
    APP_BSKY_GRAPH_DEFS#CURATELIST,    @SerialName("app.bsky.graph.defs#referencelist")
    APP_BSKY_GRAPH_DEFS#REFERENCELIST}

object AppBskyGraphDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.defs"

        @Serializable
    data class Listviewbasic(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("name")
        val name: String,        @SerialName("purpose")
        val purpose: Listpurpose,        @SerialName("avatar")
        val avatar: URI?,        @SerialName("listItemCount")
        val listItemCount: Int?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefs.Label>?,        @SerialName("viewer")
        val viewer: Listviewerstate?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#listviewbasic"
        }
    }

    @Serializable
    data class Listview(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("creator")
        val creator: AppBskyActorDefs.Profileview,        @SerialName("name")
        val name: String,        @SerialName("purpose")
        val purpose: Listpurpose,        @SerialName("description")
        val description: String?,        @SerialName("descriptionFacets")
        val descriptionFacets: List<AppBskyRichtextFacet>?,        @SerialName("avatar")
        val avatar: URI?,        @SerialName("listItemCount")
        val listItemCount: Int?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefs.Label>?,        @SerialName("viewer")
        val viewer: Listviewerstate?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#listview"
        }
    }

    @Serializable
    data class Listitemview(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("subject")
        val subject: AppBskyActorDefs.Profileview    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#listitemview"
        }
    }

    @Serializable
    data class Starterpackview(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("record")
        val record: JsonElement,        @SerialName("creator")
        val creator: AppBskyActorDefs.Profileviewbasic,        @SerialName("list")
        val list: Listviewbasic?,        @SerialName("listItemsSample")
        val listItemsSample: List<Listitemview>?,        @SerialName("feeds")
        val feeds: List<AppBskyFeedDefs.Generatorview>?,        @SerialName("joinedWeekCount")
        val joinedWeekCount: Int?,        @SerialName("joinedAllTimeCount")
        val joinedAllTimeCount: Int?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefs.Label>?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#starterpackview"
        }
    }

    @Serializable
    data class Starterpackviewbasic(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("record")
        val record: JsonElement,        @SerialName("creator")
        val creator: AppBskyActorDefs.Profileviewbasic,        @SerialName("listItemCount")
        val listItemCount: Int?,        @SerialName("joinedWeekCount")
        val joinedWeekCount: Int?,        @SerialName("joinedAllTimeCount")
        val joinedAllTimeCount: Int?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefs.Label>?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#starterpackviewbasic"
        }
    }

    @Serializable
    data class Listviewerstate(
        @SerialName("muted")
        val muted: Boolean?,        @SerialName("blocked")
        val blocked: ATProtocolURI?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#listviewerstate"
        }
    }

    /**
     * indicates that a handle or DID could not be resolved
     */
    @Serializable
    data class Notfoundactor(
        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("notFound")
        val notFound: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#notfoundactor"
        }
    }

    /**
     * lists the bi-directional graph relationships between one actor (not indicated in the object), and the target actors (the DID included in the object)
     */
    @Serializable
    data class Relationship(
        @SerialName("did")
        val did: DID,/** if the actor follows this DID, this is the AT-URI of the follow record */        @SerialName("following")
        val following: ATProtocolURI?,/** if the actor is followed by this DID, contains the AT-URI of the follow record */        @SerialName("followedBy")
        val followedBy: ATProtocolURI?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#relationship"
        }
    }

}
