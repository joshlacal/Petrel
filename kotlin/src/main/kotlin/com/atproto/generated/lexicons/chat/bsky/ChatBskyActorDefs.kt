// Lexicon: 1, ID: chat.bsky.actor.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyActorDefsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.actor.defs"
}

@Serializable(with = ChatBskyActorDefsProfileViewBasicKindUnionSerializer::class)
sealed interface ChatBskyActorDefsProfileViewBasicKindUnion {
    @Serializable
    data class DirectConvoMember(val value: com.atproto.generated.ChatBskyActorDefsDirectConvoMember) : ChatBskyActorDefsProfileViewBasicKindUnion

    @Serializable
    data class GroupConvoMember(val value: com.atproto.generated.ChatBskyActorDefsGroupConvoMember) : ChatBskyActorDefsProfileViewBasicKindUnion

    @Serializable
    data class PastGroupConvoMember(val value: com.atproto.generated.ChatBskyActorDefsPastGroupConvoMember) : ChatBskyActorDefsProfileViewBasicKindUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyActorDefsProfileViewBasicKindUnion
}

object ChatBskyActorDefsProfileViewBasicKindUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyActorDefsProfileViewBasicKindUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyActorDefsProfileViewBasicKindUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyActorDefsProfileViewBasicKindUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyActorDefsProfileViewBasicKindUnion.DirectConvoMember -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyActorDefsDirectConvoMember.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.actor.defs#directConvoMember")
                })
            }
            is ChatBskyActorDefsProfileViewBasicKindUnion.GroupConvoMember -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyActorDefsGroupConvoMember.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.actor.defs#groupConvoMember")
                })
            }
            is ChatBskyActorDefsProfileViewBasicKindUnion.PastGroupConvoMember -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyActorDefsPastGroupConvoMember.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.actor.defs#pastGroupConvoMember")
                })
            }
            is ChatBskyActorDefsProfileViewBasicKindUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyActorDefsProfileViewBasicKindUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.actor.defs#directConvoMember" -> ChatBskyActorDefsProfileViewBasicKindUnion.DirectConvoMember(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyActorDefsDirectConvoMember.serializer(), element)
            )
            "chat.bsky.actor.defs#groupConvoMember" -> ChatBskyActorDefsProfileViewBasicKindUnion.GroupConvoMember(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyActorDefsGroupConvoMember.serializer(), element)
            )
            "chat.bsky.actor.defs#pastGroupConvoMember" -> ChatBskyActorDefsProfileViewBasicKindUnion.PastGroupConvoMember(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyActorDefsPastGroupConvoMember.serializer(), element)
            )
            else -> ChatBskyActorDefsProfileViewBasicKindUnion.Unexpected(element)
        }
    }
}

@Serializable
enum class ChatBskyActorDefsMemberRole {
    @SerialName("owner")
    OWNER,
    @SerialName("standard")
    STANDARD}

    @Serializable
    data class ChatBskyActorDefsProfileViewBasic(
        @SerialName("did")
        val did: DID,        @SerialName("handle")
        val handle: Handle,        @SerialName("displayName")
        val displayName: String? = null,        @SerialName("avatar")
        val avatar: URI? = null,        @SerialName("associated")
        val associated: AppBskyActorDefsProfileAssociated? = null,        @SerialName("viewer")
        val viewer: AppBskyActorDefsViewerState? = null,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate? = null,/** Set to true when the actor cannot actively participate in conversations */        @SerialName("chatDisabled")
        val chatDisabled: Boolean? = null,        @SerialName("verification")
        val verification: AppBskyActorDefsVerificationState? = null,/** Union field that has data specific to different kinds of convos. */        @SerialName("kind")
        val kind: ChatBskyActorDefsProfileViewBasicKindUnion? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyActorDefsProfileViewBasic"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here].
     */
    @Serializable
    class ChatBskyActorDefsDirectConvoMember {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyActorDefsDirectConvoMember"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. A current group convo member.
     */
    @Serializable
    data class ChatBskyActorDefsGroupConvoMember(
/** Who added this member. Only present if the member was added (instead of joining via link). */        @SerialName("addedBy")
        val addedBy: ChatBskyActorDefsProfileViewBasic? = null,/** The member's role within this conversation. Only present in group conversation member lists. */        @SerialName("role")
        val role: ChatBskyActorDefsMemberRole    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyActorDefsGroupConvoMember"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. A past group convo member.
     */
    @Serializable
    class ChatBskyActorDefsPastGroupConvoMember {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyActorDefsPastGroupConvoMember"
        }
    }
