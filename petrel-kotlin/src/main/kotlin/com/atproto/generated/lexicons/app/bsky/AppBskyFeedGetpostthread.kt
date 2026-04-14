// Lexicon: 1, ID: app.bsky.feed.getPostThread
// Get posts in a thread. Does not require auth, but additional metadata and filtering will be applied for authed requests.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedGetPostThreadDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getPostThread"
}

@Serializable(with = AppBskyFeedGetPostThreadOutputThreadUnionSerializer::class)
sealed interface AppBskyFeedGetPostThreadOutputThreadUnion {
    @Serializable
    data class ThreadViewPost(val value: com.atproto.generated.AppBskyFeedDefsThreadViewPost) : AppBskyFeedGetPostThreadOutputThreadUnion

    @Serializable
    data class NotFoundPost(val value: com.atproto.generated.AppBskyFeedDefsNotFoundPost) : AppBskyFeedGetPostThreadOutputThreadUnion

    @Serializable
    data class BlockedPost(val value: com.atproto.generated.AppBskyFeedDefsBlockedPost) : AppBskyFeedGetPostThreadOutputThreadUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyFeedGetPostThreadOutputThreadUnion
}

object AppBskyFeedGetPostThreadOutputThreadUnionSerializer : kotlinx.serialization.KSerializer<AppBskyFeedGetPostThreadOutputThreadUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyFeedGetPostThreadOutputThreadUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyFeedGetPostThreadOutputThreadUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyFeedGetPostThreadOutputThreadUnion.ThreadViewPost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsThreadViewPost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#threadViewPost")
                })
            }
            is AppBskyFeedGetPostThreadOutputThreadUnion.NotFoundPost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsNotFoundPost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#notFoundPost")
                })
            }
            is AppBskyFeedGetPostThreadOutputThreadUnion.BlockedPost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsBlockedPost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#blockedPost")
                })
            }
            is AppBskyFeedGetPostThreadOutputThreadUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyFeedGetPostThreadOutputThreadUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.feed.defs#threadViewPost" -> AppBskyFeedGetPostThreadOutputThreadUnion.ThreadViewPost(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsThreadViewPost.serializer(), element)
            )
            "app.bsky.feed.defs#notFoundPost" -> AppBskyFeedGetPostThreadOutputThreadUnion.NotFoundPost(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsNotFoundPost.serializer(), element)
            )
            "app.bsky.feed.defs#blockedPost" -> AppBskyFeedGetPostThreadOutputThreadUnion.BlockedPost(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsBlockedPost.serializer(), element)
            )
            else -> AppBskyFeedGetPostThreadOutputThreadUnion.Unexpected(element)
        }
    }
}

@Serializable
    data class AppBskyFeedGetPostThreadParameters(
// Reference (AT-URI) to post record.        @SerialName("uri")
        val uri: ATProtocolURI,// How many levels of reply depth should be included in response.        @SerialName("depth")
        val depth: Int? = null,// How many levels of parent (and grandparent, etc) post to include.        @SerialName("parentHeight")
        val parentHeight: Int? = null    )

    @Serializable
    data class AppBskyFeedGetPostThreadOutput(
        @SerialName("thread")
        val thread: AppBskyFeedGetPostThreadOutputThreadUnion,        @SerialName("threadgate")
        val threadgate: AppBskyFeedDefsThreadgateView? = null    )

sealed class AppBskyFeedGetPostThreadError(val name: String, val description: String?) {
        object NotFound: AppBskyFeedGetPostThreadError("NotFound", "")
    }

/**
 * Get posts in a thread. Does not require auth, but additional metadata and filtering will be applied for authed requests.
 *
 * Endpoint: app.bsky.feed.getPostThread
 */
suspend fun ATProtoClient.App.Bsky.Feed.getPostThread(
parameters: AppBskyFeedGetPostThreadParameters): ATProtoResponse<AppBskyFeedGetPostThreadOutput> {
    val endpoint = "app.bsky.feed.getPostThread"

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
