// Lexicon: 1, ID: app.bsky.embed.record
// A representation of a record embedded in a Bluesky record (eg, a post). For example, a quote-post, or sharing a feed generator record.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyEmbedRecordDefs {
    const val TYPE_IDENTIFIER = "app.bsky.embed.record"
}

@Serializable(with = AppBskyEmbedRecordViewRecordUnionSerializer::class)
sealed interface AppBskyEmbedRecordViewRecordUnion {
    @Serializable
    data class ViewRecord(val value: blue.catbird.petrel.generated.AppBskyEmbedRecordViewRecord) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    data class ViewNotFound(val value: blue.catbird.petrel.generated.AppBskyEmbedRecordViewNotFound) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    data class ViewBlocked(val value: blue.catbird.petrel.generated.AppBskyEmbedRecordViewBlocked) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    data class ViewDetached(val value: blue.catbird.petrel.generated.AppBskyEmbedRecordViewDetached) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    data class GeneratorView(val value: blue.catbird.petrel.generated.AppBskyFeedDefsGeneratorView) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    data class ListView(val value: blue.catbird.petrel.generated.AppBskyGraphDefsListView) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    data class LabelerView(val value: blue.catbird.petrel.generated.AppBskyLabelerDefsLabelerView) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    data class StarterPackViewBasic(val value: blue.catbird.petrel.generated.AppBskyGraphDefsStarterPackViewBasic) : AppBskyEmbedRecordViewRecordUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedRecordViewRecord.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.record#viewRecord")
                })
            }
            is AppBskyEmbedRecordViewRecordUnion.ViewNotFound -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedRecordViewNotFound.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.record#viewNotFound")
                })
            }
            is AppBskyEmbedRecordViewRecordUnion.ViewBlocked -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedRecordViewBlocked.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.record#viewBlocked")
                })
            }
            is AppBskyEmbedRecordViewRecordUnion.ViewDetached -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedRecordViewDetached.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.record#viewDetached")
                })
            }
            is AppBskyEmbedRecordViewRecordUnion.GeneratorView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyFeedDefsGeneratorView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#generatorView")
                })
            }
            is AppBskyEmbedRecordViewRecordUnion.ListView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyGraphDefsListView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.graph.defs#listView")
                })
            }
            is AppBskyEmbedRecordViewRecordUnion.LabelerView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyLabelerDefsLabelerView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.labeler.defs#labelerView")
                })
            }
            is AppBskyEmbedRecordViewRecordUnion.StarterPackViewBasic -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyGraphDefsStarterPackViewBasic.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.graph.defs#starterPackViewBasic")
                })
            }
            is AppBskyEmbedRecordViewRecordUnion.Unexpected -> value.value
            // Synthetic variants (e.g. <Union>Error / <Union>Unexpected added by
            // subscription codegen) are runtime-only sentinels; JSON round-trip
            // serialises them as an empty object tagged with the variant class
            // name. Consumers should filter these before JSON serialisation.
            else -> kotlinx.serialization.json.buildJsonObject {
                put("\$type", kotlinx.serialization.json.JsonPrimitive(value::class.simpleName ?: "Unknown"))
            }
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
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedRecordViewRecord.serializer(), element)
            )
            "app.bsky.embed.record#viewNotFound" -> AppBskyEmbedRecordViewRecordUnion.ViewNotFound(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedRecordViewNotFound.serializer(), element)
            )
            "app.bsky.embed.record#viewBlocked" -> AppBskyEmbedRecordViewRecordUnion.ViewBlocked(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedRecordViewBlocked.serializer(), element)
            )
            "app.bsky.embed.record#viewDetached" -> AppBskyEmbedRecordViewRecordUnion.ViewDetached(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedRecordViewDetached.serializer(), element)
            )
            "app.bsky.feed.defs#generatorView" -> AppBskyEmbedRecordViewRecordUnion.GeneratorView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyFeedDefsGeneratorView.serializer(), element)
            )
            "app.bsky.graph.defs#listView" -> AppBskyEmbedRecordViewRecordUnion.ListView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyGraphDefsListView.serializer(), element)
            )
            "app.bsky.labeler.defs#labelerView" -> AppBskyEmbedRecordViewRecordUnion.LabelerView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyLabelerDefsLabelerView.serializer(), element)
            )
            "app.bsky.graph.defs#starterPackViewBasic" -> AppBskyEmbedRecordViewRecordUnion.StarterPackViewBasic(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyGraphDefsStarterPackViewBasic.serializer(), element)
            )
            else -> AppBskyEmbedRecordViewRecordUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyEmbedRecordViewRecordEmbedsUnionSerializer::class)
sealed interface AppBskyEmbedRecordViewRecordEmbedsUnion {
    @Serializable
    data class View(val value: blue.catbird.petrel.generated.AppBskyEmbedImagesView) : AppBskyEmbedRecordViewRecordEmbedsUnion

    @Serializable
    data class AppBskyEmbedVideoView(val value: blue.catbird.petrel.generated.AppBskyEmbedVideoView) : AppBskyEmbedRecordViewRecordEmbedsUnion

    @Serializable
    data class AppBskyEmbedGalleryView(val value: blue.catbird.petrel.generated.AppBskyEmbedGalleryView) : AppBskyEmbedRecordViewRecordEmbedsUnion

    @Serializable
    data class AppBskyEmbedExternalView(val value: blue.catbird.petrel.generated.AppBskyEmbedExternalView) : AppBskyEmbedRecordViewRecordEmbedsUnion

    @Serializable
    data class AppBskyEmbedRecordView(val value: blue.catbird.petrel.generated.AppBskyEmbedRecordView) : AppBskyEmbedRecordViewRecordEmbedsUnion

    @Serializable
    data class AppBskyEmbedRecordWithMediaView(val value: blue.catbird.petrel.generated.AppBskyEmbedRecordWithMediaView) : AppBskyEmbedRecordViewRecordEmbedsUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedImagesView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.images#view")
                })
            }
            is AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedVideoView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedVideoView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.video#view")
                })
            }
            is AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedGalleryView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedGalleryView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.gallery#view")
                })
            }
            is AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedExternalView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedExternalView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.external#view")
                })
            }
            is AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedRecordView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedRecordView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.record#view")
                })
            }
            is AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedRecordWithMediaView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedRecordWithMediaView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.recordWithMedia#view")
                })
            }
            is AppBskyEmbedRecordViewRecordEmbedsUnion.Unexpected -> value.value
            // Synthetic variants (e.g. <Union>Error / <Union>Unexpected added by
            // subscription codegen) are runtime-only sentinels; JSON round-trip
            // serialises them as an empty object tagged with the variant class
            // name. Consumers should filter these before JSON serialisation.
            else -> kotlinx.serialization.json.buildJsonObject {
                put("\$type", kotlinx.serialization.json.JsonPrimitive(value::class.simpleName ?: "Unknown"))
            }
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
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedImagesView.serializer(), element)
            )
            "app.bsky.embed.video#view" -> AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedVideoView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedVideoView.serializer(), element)
            )
            "app.bsky.embed.gallery#view" -> AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedGalleryView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedGalleryView.serializer(), element)
            )
            "app.bsky.embed.external#view" -> AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedExternalView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedExternalView.serializer(), element)
            )
            "app.bsky.embed.record#view" -> AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedRecordView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedRecordView.serializer(), element)
            )
            "app.bsky.embed.recordWithMedia#view" -> AppBskyEmbedRecordViewRecordEmbedsUnion.AppBskyEmbedRecordWithMediaView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedRecordWithMediaView.serializer(), element)
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
