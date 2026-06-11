// Lexicon: 1, ID: app.bsky.actor.status
// A declaration of a Bluesky account status.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyActorStatusDefs {
    const val TYPE_IDENTIFIER = "app.bsky.actor.status"
}

@Serializable(with = AppBskyActorStatusEmbedUnionSerializer::class)
sealed interface AppBskyActorStatusEmbedUnion {
    @Serializable
    data class External(val value: blue.catbird.petrel.generated.AppBskyEmbedExternal) : AppBskyActorStatusEmbedUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyActorStatusEmbedUnion
}

object AppBskyActorStatusEmbedUnionSerializer : kotlinx.serialization.KSerializer<AppBskyActorStatusEmbedUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyActorStatusEmbedUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyActorStatusEmbedUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyActorStatusEmbedUnion.External -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedExternal.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.external")
                })
            }
            is AppBskyActorStatusEmbedUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyActorStatusEmbedUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.embed.external" -> AppBskyActorStatusEmbedUnion.External(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedExternal.serializer(), element)
            )
            else -> AppBskyActorStatusEmbedUnion.Unexpected(element)
        }
    }
}

    /**
     * A declaration of a Bluesky account status.
     */
    @Serializable
    data class AppBskyActorStatus(
/** The status for the account. */        @SerialName("status")
        val status: String,/** An optional embed associated with the status. */        @SerialName("embed")
        val embed: AppBskyActorStatusEmbedUnion? = null,/** The duration of the status in minutes. Applications can choose to impose minimum and maximum limits. */        @SerialName("durationMinutes")
        val durationMinutes: Int? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
