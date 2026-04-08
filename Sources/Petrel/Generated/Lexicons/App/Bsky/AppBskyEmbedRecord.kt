// Lexicon: 1, ID: app.bsky.embed.record
// A representation of a record embedded in a Bluesky record (eg, a post). For example, a quote-post, or sharing a feed generator record.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyEmbedRecordDefs {
    const val TYPE_IDENTIFIER = "app.bsky.embed.record"
}

@Serializable(with = AppBskyEmbedRecordViewRecordUnionSerializer::class)
sealed interface AppBskyEmbedRecordViewRecordUnion {
    @Serializable
    data class ViewRecord(val value: com.atproto.generated.AppBskyEmbedRecordViewRecord) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    data class ViewNotFound(val value: com.atproto.generated.AppBskyEmbedRecordViewNotFound) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    data class ViewBlocked(val value: com.atproto.generated.AppBskyEmbedRecordViewBlocked) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    data class ViewDetached(val value: com.atproto.generated.AppBskyEmbedRecordViewDetached) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    data class GeneratorView(val value: com.atproto.generated.AppBskyFeedDefsGeneratorView) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    data class ListView(val value: com.atproto.generated.AppBskyGraphDefsListView) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    data class LabelerView(val value: com.atproto.generated.AppBskyLabelerDefsLabelerView) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    data class StarterPackViewBasic(val value: com.atproto.generated.AppBskyGraphDefsStarterPackViewBasic) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyEmbedRecordViewRecordUnion
}

object AppBskyEmbedRecordViewRecordUnionSerializer : kotlinx.serialization.KSerializer<AppBskyEmbedRecordViewRecordUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyEmbedRecordViewRecordUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyEmbedRecordViewRecordUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyEmbedRecordViewRecordUnion.ViewRecord -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedRecordViewRecord.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.record#viewRecord")
                })
            }
            is AppBskyEmbedRecordViewRecordUnion.ViewNotFound -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedRecordViewNotFound.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.record#viewNotFound")
                })
            }
            is AppBskyEmbedRecordViewRecordUnion.ViewBlocked -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedRecordViewBlocked.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.record#viewBlocked")
                })
            }
            is AppBskyEmbedRecordViewRecordUnion.ViewDetached -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedRecordViewDetached.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.record#viewDetached")
                })
            }
            is AppBskyEmbedRecordViewRecordUnion.GeneratorView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsGeneratorView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#generatorView")
                })
            }
            is AppBskyEmbedRecordViewRecordUnion.ListView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyGraphDefsListView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.graph.defs#listView")
                })
            }
            is AppBskyEmbedRecordViewRecordUnion.LabelerView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyLabelerDefsLabelerView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.labeler.defs#labelerView")
                })
            }
            is AppBskyEmbedRecordViewRecordUnion.StarterPackViewBasic -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyGraphDefsStarterPackViewBasic.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.graph.defs#starterPackViewBasic")
                })
            }
            is AppBskyEmbedRecordViewRecordUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyEmbedRecordViewRecordUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.embed.record#viewRecord" -> AppBskyEmbedRecordViewRecordUnion.ViewRecord(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedRecordViewRecord.serializer(), element)
            )
            "app.bsky.embed.record#viewNotFound" -> AppBskyEmbedRecordViewRecordUnion.ViewNotFound(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedRecordViewNotFound.serializer(), element)
            )
            "app.bsky.embed.record#viewBlocked" -> AppBskyEmbedRecordViewRecordUnion.ViewBlocked(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedRecordViewBlocked.serializer(), element)
            )
            "app.bsky.embed.record#viewDetached" -> AppBskyEmbedRecordViewRecordUnion.ViewDetached(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedRecordViewDetached.serializer(), element)
            )
            "app.bsky.feed.defs#generatorView" -> AppBskyEmbedRecordViewRecordUnion.GeneratorView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsGeneratorView.serializer(), element)
            )
            "app.bsky.graph.defs#listView" -> AppBskyEmbedRecordViewRecordUnion.ListView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyGraphDefsListView.serializer(), element)
            )
            "app.bsky.labeler.defs#labelerView" -> AppBskyEmbedRecordViewRecordUnion.LabelerView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyLabelerDefsLabelerView.serializer(), element)
            )
            "app.bsky.graph.defs#starterPackViewBasic" -> AppBskyEmbedRecordViewRecordUnion.StarterPackViewBasic(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyGraphDefsStarterPackViewBasic.serializer(), element)
            )
            else -> AppBskyEmbedRecordViewRecordUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyEmbedRecordViewRecordEmbedsUnionSerializer::class)
sealed interface AppBskyEmbedRecordViewRecordEmbedsUnion {
    @Serializable
    data class View(val value: com.atproto.generated.AppBskyEmbedImagesView) : AppBskyEmbedRecordViewRecordEmbedsUnion

    @Serializable
    data class AppBskyEmbedVideoView(val value: com.atproto.generated.AppBskyEmbedVideoView) : AppBskyEmbedRecordViewRecordEmbedsUnion

    @Serializable
    data class AppBskyEmbedExternalView(val value: com.atproto.generated.AppBskyEmbedExternalView) : AppBskyEmbedRecordViewRecordEmbedsUnion

    @Serializable
    data class AppBskyEmbedRecordView(val value: com.atproto.generated.AppBskyEmbedRecordView) : AppBskyEmbedRecordViewRecordEmbedsUnion

    @Serializable
    data class AppBskyEmbedRecordWithMediaView(val value: com.atproto.generated.AppBskyEmbedRecordWithMediaView) : AppBskyEmbedRecordViewRecordEmbedsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyEmbedRecordViewRecordEmbedsUnion
}

object AppBskyEmbedRecordViewRecordEmbedsUnionSerializer : kotlinx.serialization.KSerializer<AppBskyEmbedRecordViewRecordEmbedsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyEmbedRecordViewRecordEmbedsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyEmbedRecordViewRecordEmbedsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyEmbedRecordViewRecordEmbedsUnion.View -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedImagesView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.images#view")
                })
            }
            is AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedVideoView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedVideoView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.video#view")
                })
            }
            is AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedExternalView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedExternalView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.external#view")
                })
            }
            is AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedRecordView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedRecordView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.record#view")
                })
            }
            is AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedRecordWithMediaView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedRecordWithMediaView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.recordWithMedia#view")
                })
            }
            is AppBskyEmbedRecordViewRecordEmbedsUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyEmbedRecordViewRecordEmbedsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.embed.images#view" -> AppBskyEmbedRecordViewRecordEmbedsUnion.View(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedImagesView.serializer(), element)
            )
            "app.bsky.embed.video#view" -> AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedVideoView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedVideoView.serializer(), element)
            )
            "app.bsky.embed.external#view" -> AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedExternalView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedExternalView.serializer(), element)
            )
            "app.bsky.embed.record#view" -> AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedRecordView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedRecordView.serializer(), element)
            )
            "app.bsky.embed.recordWithMedia#view" -> AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedRecordWithMediaView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedRecordWithMediaView.serializer(), element)
            )
            else -> AppBskyEmbedRecordViewRecordEmbedsUnion.Unexpected(element)
        }
    }
}

    @Serializable
    data class AppBskyEmbedRecordView(
        @SerialName("record")
        val record: AppBskyEmbedRecordViewRecordUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedRecordView"
        }
    }

    @Serializable
    data class AppBskyEmbedRecordViewRecord(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("author")
        val author: AppBskyActorDefsProfileViewBasic,/** The record data itself. */        @SerialName("value")
        val value: JsonElement,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>? = null,        @SerialName("replyCount")
        val replyCount: Int? = null,        @SerialName("repostCount")
        val repostCount: Int? = null,        @SerialName("likeCount")
        val likeCount: Int? = null,        @SerialName("quoteCount")
        val quoteCount: Int? = null,        @SerialName("embeds")
        val embeds: List<AppBskyEmbedRecordViewRecordEmbedsUnion>? = null,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedRecordViewRecord"
        }
    }

    @Serializable
    data class AppBskyEmbedRecordViewNotFound(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("notFound")
        val notFound: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedRecordViewNotFound"
        }
    }

    @Serializable
    data class AppBskyEmbedRecordViewBlocked(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("blocked")
        val blocked: Boolean,        @SerialName("author")
        val author: AppBskyFeedDefsBlockedAuthor    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedRecordViewBlocked"
        }
    }

    @Serializable
    data class AppBskyEmbedRecordViewDetached(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("detached")
        val detached: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedRecordViewDetached"
        }
    }

@Serializable
data class AppBskyEmbedRecord(
    @SerialName("record")
    val record: ComAtprotoRepoStrongRef)
