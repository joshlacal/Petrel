// Lexicon: 1, ID: app.bsky.bookmark.defs

package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyBookmarkDefsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.bookmark.defs"
}

@Serializable(with = AppBskyBookmarkDefsBookmarkViewItemUnionSerializer::class)
sealed interface AppBskyBookmarkDefsBookmarkViewItemUnion {
    @Serializable
    data class BlockedPost(val value: blue.catbird.petrel.generated.AppBskyFeedDefsBlockedPost) : AppBskyBookmarkDefsBookmarkViewItemUnion

    @Serializable
    data class NotFoundPost(val value: blue.catbird.petrel.generated.AppBskyFeedDefsNotFoundPost) : AppBskyBookmarkDefsBookmarkViewItemUnion

    @Serializable
    data class PostView(val value: blue.catbird.petrel.generated.AppBskyFeedDefsPostView) : AppBskyBookmarkDefsBookmarkViewItemUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyBookmarkDefsBookmarkViewItemUnion
}

object AppBskyBookmarkDefsBookmarkViewItemUnionSerializer : kotlinx.serialization.KSerializer<AppBskyBookmarkDefsBookmarkViewItemUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyBookmarkDefsBookmarkViewItemUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyBookmarkDefsBookmarkViewItemUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyBookmarkDefsBookmarkViewItemUnion.BlockedPost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyFeedDefsBlockedPost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#blockedPost")
                })
            }
            is AppBskyBookmarkDefsBookmarkViewItemUnion.NotFoundPost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyFeedDefsNotFoundPost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#notFoundPost")
                })
            }
            is AppBskyBookmarkDefsBookmarkViewItemUnion.PostView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyFeedDefsPostView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#postView")
                })
            }
            is AppBskyBookmarkDefsBookmarkViewItemUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyBookmarkDefsBookmarkViewItemUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.feed.defs#blockedPost" -> AppBskyBookmarkDefsBookmarkViewItemUnion.BlockedPost(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyFeedDefsBlockedPost.serializer(), element)
            )
            "app.bsky.feed.defs#notFoundPost" -> AppBskyBookmarkDefsBookmarkViewItemUnion.NotFoundPost(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyFeedDefsNotFoundPost.serializer(), element)
            )
            "app.bsky.feed.defs#postView" -> AppBskyBookmarkDefsBookmarkViewItemUnion.PostView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyFeedDefsPostView.serializer(), element)
            )
            else -> AppBskyBookmarkDefsBookmarkViewItemUnion.Unexpected(element)
        }
    }
}

    /**
     * Object used to store bookmark data in stash.
     */
    @Serializable
    data class AppBskyBookmarkDefsBookmark(
/** A strong ref to the record to be bookmarked. Currently, only `app.bsky.feed.post` records are supported. */        @SerialName("subject")
        val subject: ComAtprotoRepoStrongRef    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyBookmarkDefsBookmark"
        }
    }

    @Serializable
    data class AppBskyBookmarkDefsBookmarkView(
/** A strong ref to the bookmarked record. */        @SerialName("subject")
        val subject: ComAtprotoRepoStrongRef,        @SerialName("createdAt")
        val createdAt: ATProtocolDate? = null,        @SerialName("item")
        val item: AppBskyBookmarkDefsBookmarkViewItemUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyBookmarkDefsBookmarkView"
        }
    }
