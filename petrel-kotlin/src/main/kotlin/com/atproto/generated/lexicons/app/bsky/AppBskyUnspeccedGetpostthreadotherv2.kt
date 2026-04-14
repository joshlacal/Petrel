// Lexicon: 1, ID: app.bsky.unspecced.getPostThreadOtherV2
// (NOTE: this endpoint is under development and WILL change without notice. Don't use it until it is moved out of `unspecced` or your application WILL break) Get additional posts under a thread e.g. replies hidden by threadgate. Based on an anchor post at any depth of the tree, returns top-level replies below that anchor. It does not include ancestors nor the anchor itself. This should be called after exhausting `app.bsky.unspecced.getPostThreadV2`. Does not require auth, but additional metadata and filtering will be applied for authed requests.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetPostThreadOtherV2Defs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getPostThreadOtherV2"
}

@Serializable(with = AppBskyUnspeccedGetPostThreadOtherV2ThreadItemValueUnionSerializer::class)
sealed interface AppBskyUnspeccedGetPostThreadOtherV2ThreadItemValueUnion {
    @Serializable
    data class ThreadItemPost(val value: com.atproto.generated.AppBskyUnspeccedDefsThreadItemPost) : AppBskyUnspeccedGetPostThreadOtherV2ThreadItemValueUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyUnspeccedGetPostThreadOtherV2ThreadItemValueUnion
}

object AppBskyUnspeccedGetPostThreadOtherV2ThreadItemValueUnionSerializer : kotlinx.serialization.KSerializer<AppBskyUnspeccedGetPostThreadOtherV2ThreadItemValueUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyUnspeccedGetPostThreadOtherV2ThreadItemValueUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyUnspeccedGetPostThreadOtherV2ThreadItemValueUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyUnspeccedGetPostThreadOtherV2ThreadItemValueUnion.ThreadItemPost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyUnspeccedDefsThreadItemPost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.unspecced.defs#threadItemPost")
                })
            }
            is AppBskyUnspeccedGetPostThreadOtherV2ThreadItemValueUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyUnspeccedGetPostThreadOtherV2ThreadItemValueUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.unspecced.defs#threadItemPost" -> AppBskyUnspeccedGetPostThreadOtherV2ThreadItemValueUnion.ThreadItemPost(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyUnspeccedDefsThreadItemPost.serializer(), element)
            )
            else -> AppBskyUnspeccedGetPostThreadOtherV2ThreadItemValueUnion.Unexpected(element)
        }
    }
}

    @Serializable
    data class AppBskyUnspeccedGetPostThreadOtherV2ThreadItem(
        @SerialName("uri")
        val uri: ATProtocolURI,/** The nesting level of this item in the thread. Depth 0 means the anchor item. Items above have negative depths, items below have positive depths. */        @SerialName("depth")
        val depth: Int,        @SerialName("value")
        val value: AppBskyUnspeccedGetPostThreadOtherV2ThreadItemValueUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyUnspeccedGetPostThreadOtherV2ThreadItem"
        }
    }

@Serializable
    data class AppBskyUnspeccedGetPostThreadOtherV2Parameters(
// Reference (AT-URI) to post record. This is the anchor post.        @SerialName("anchor")
        val anchor: ATProtocolURI    )

    @Serializable
    data class AppBskyUnspeccedGetPostThreadOtherV2Output(
// A flat list of other thread items. The depth of each item is indicated by the depth property inside the item.        @SerialName("thread")
        val thread: List<AppBskyUnspeccedGetPostThreadOtherV2ThreadItem>    )

/**
 * (NOTE: this endpoint is under development and WILL change without notice. Don't use it until it is moved out of `unspecced` or your application WILL break) Get additional posts under a thread e.g. replies hidden by threadgate. Based on an anchor post at any depth of the tree, returns top-level replies below that anchor. It does not include ancestors nor the anchor itself. This should be called after exhausting `app.bsky.unspecced.getPostThreadV2`. Does not require auth, but additional metadata and filtering will be applied for authed requests.
 *
 * Endpoint: app.bsky.unspecced.getPostThreadOtherV2
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getPostThreadOtherV2(
parameters: AppBskyUnspeccedGetPostThreadOtherV2Parameters): ATProtoResponse<AppBskyUnspeccedGetPostThreadOtherV2Output> {
    val endpoint = "app.bsky.unspecced.getPostThreadOtherV2"

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
