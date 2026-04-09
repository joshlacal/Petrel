// Lexicon: 1, ID: app.bsky.actor.profile
// A declaration of a Bluesky account profile.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyActorProfileDefs {
    const val TYPE_IDENTIFIER = "app.bsky.actor.profile"
}

@Serializable(with = AppBskyActorProfileLabelsUnionSerializer::class)
sealed interface AppBskyActorProfileLabelsUnion {
    @Serializable
    data class SelfLabels(val value: com.atproto.generated.ComAtprotoLabelDefsSelfLabels) : AppBskyActorProfileLabelsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyActorProfileLabelsUnion
}

object AppBskyActorProfileLabelsUnionSerializer : kotlinx.serialization.KSerializer<AppBskyActorProfileLabelsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyActorProfileLabelsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyActorProfileLabelsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyActorProfileLabelsUnion.SelfLabels -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoLabelDefsSelfLabels.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.label.defs#selfLabels")
                })
            }
            is AppBskyActorProfileLabelsUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyActorProfileLabelsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.label.defs#selfLabels" -> AppBskyActorProfileLabelsUnion.SelfLabels(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoLabelDefsSelfLabels.serializer(), element)
            )
            else -> AppBskyActorProfileLabelsUnion.Unexpected(element)
        }
    }
}

    /**
     * A declaration of a Bluesky account profile.
     */
    @Serializable
    data class AppBskyActorProfile(
        @SerialName("displayName")
        val displayName: String? = null,/** Free-form profile description text. */        @SerialName("description")
        val description: String? = null,/** Free-form pronouns text. */        @SerialName("pronouns")
        val pronouns: String? = null,        @SerialName("website")
        val website: URI? = null,/** Small image to be displayed next to posts from account. AKA, 'profile picture' */        @SerialName("avatar")
        val avatar: Blob? = null,/** Larger horizontal image to display behind profile view. */        @SerialName("banner")
        val banner: Blob? = null,/** Self-label values, specific to the Bluesky application, on the overall account. */        @SerialName("labels")
        val labels: AppBskyActorProfileLabelsUnion? = null,        @SerialName("joinedViaStarterPack")
        val joinedViaStarterPack: ComAtprotoRepoStrongRef? = null,        @SerialName("pinnedPost")
        val pinnedPost: ComAtprotoRepoStrongRef? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
