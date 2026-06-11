// Lexicon: 1, ID: app.bsky.unspecced.getPostThreadV2
// (NOTE: this endpoint is under development and WILL change without notice. Don't use it until it is moved out of `unspecced` or your application WILL break) Get posts in a thread. It is based in an anchor post at any depth of the tree, and returns posts above it (recursively resolving the parent, without further branching to their replies) and below it (recursive replies, with branching to their replies). Does not require auth, but additional metadata and filtering will be applied for authed requests.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetPostThreadV2Defs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getPostThreadV2"
}

@Serializable(with = AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnionSerializer::class)
sealed interface AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion {
    @Serializable
    data class ThreadItemPost(val value: blue.catbird.petrel.generated.AppBskyUnspeccedDefsThreadItemPost) : AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion

    @Serializable
    data class ThreadItemNoUnauthenticated(val value: blue.catbird.petrel.generated.AppBskyUnspeccedDefsThreadItemNoUnauthenticated) : AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion

    @Serializable
    data class ThreadItemNotFound(val value: blue.catbird.petrel.generated.AppBskyUnspeccedDefsThreadItemNotFound) : AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion

    @Serializable
    data class ThreadItemBlocked(val value: blue.catbird.petrel.generated.AppBskyUnspeccedDefsThreadItemBlocked) : AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion
}

object AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnionSerializer : kotlinx.serialization.KSerializer<AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion.ThreadItemPost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyUnspeccedDefsThreadItemPost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.unspecced.defs#threadItemPost")
                })
            }
            is AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion.ThreadItemNoUnauthenticated -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyUnspeccedDefsThreadItemNoUnauthenticated.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.unspecced.defs#threadItemNoUnauthenticated")
                })
            }
            is AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion.ThreadItemNotFound -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyUnspeccedDefsThreadItemNotFound.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.unspecced.defs#threadItemNotFound")
                })
            }
            is AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion.ThreadItemBlocked -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyUnspeccedDefsThreadItemBlocked.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.unspecced.defs#threadItemBlocked")
                })
            }
            is AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.unspecced.defs#threadItemPost" -> AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion.ThreadItemPost(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyUnspeccedDefsThreadItemPost.serializer(), element)
            )
            "app.bsky.unspecced.defs#threadItemNoUnauthenticated" -> AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion.ThreadItemNoUnauthenticated(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyUnspeccedDefsThreadItemNoUnauthenticated.serializer(), element)
            )
            "app.bsky.unspecced.defs#threadItemNotFound" -> AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion.ThreadItemNotFound(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyUnspeccedDefsThreadItemNotFound.serializer(), element)
            )
            "app.bsky.unspecced.defs#threadItemBlocked" -> AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion.ThreadItemBlocked(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyUnspeccedDefsThreadItemBlocked.serializer(), element)
            )
            else -> AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion.Unexpected(element)
        }
    }
}

    @Serializable
    data class AppBskyUnspeccedGetPostThreadV2ThreadItem(
        @SerialName("uri")
        val uri: ATProtocolURI,/** The nesting level of this item in the thread. Depth 0 means the anchor item. Items above have negative depths, items below have positive depths. */        @SerialName("depth")
        val depth: Int,        @SerialName("value")
        val value: AppBskyUnspeccedGetPostThreadV2ThreadItemValueUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyUnspeccedGetPostThreadV2ThreadItem"
        }
    }

@Serializable
    data class AppBskyUnspeccedGetPostThreadV2Parameters(
// Reference (AT-URI) to post record. This is the anchor post, and the thread will be built around it. It can be any post in the tree, not necessarily a root post.        @SerialName("anchor")
        val anchor: ATProtocolURI,// Whether to include parents above the anchor.        @SerialName("above")
        val above: Boolean? = null,// How many levels of replies to include below the anchor.        @SerialName("below")
        val below: Int? = null,// Maximum of replies to include at each level of the thread, except for the direct replies to the anchor, which are (NOTE: currently, during unspecced phase) all returned (NOTE: later they might be paginated).        @SerialName("branchingFactor")
        val branchingFactor: Int? = null,// Sorting for the thread replies.        @SerialName("sort")
        val sort: String? = null    )

    @Serializable
    data class AppBskyUnspeccedGetPostThreadV2Output(
// A flat list of thread items. The depth of each item is indicated by the depth property inside the item.        @SerialName("thread")
        val thread: List<AppBskyUnspeccedGetPostThreadV2ThreadItem>,        @SerialName("threadgate")
        val threadgate: AppBskyFeedDefsThreadgateView? = null,// Whether this thread has additional replies. If true, a call can be made to the `getPostThreadOtherV2` endpoint to retrieve them.        @SerialName("hasOtherReplies")
        val hasOtherReplies: Boolean    )

/**
 * (NOTE: this endpoint is under development and WILL change without notice. Don't use it until it is moved out of `unspecced` or your application WILL break) Get posts in a thread. It is based in an anchor post at any depth of the tree, and returns posts above it (recursively resolving the parent, without further branching to their replies) and below it (recursive replies, with branching to their replies). Does not require auth, but additional metadata and filtering will be applied for authed requests.
 *
 * Endpoint: app.bsky.unspecced.getPostThreadV2
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getPostThreadV2(
parameters: AppBskyUnspeccedGetPostThreadV2Parameters): ATProtoResponse<AppBskyUnspeccedGetPostThreadV2Output> {
    val endpoint = "app.bsky.unspecced.getPostThreadV2"

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
