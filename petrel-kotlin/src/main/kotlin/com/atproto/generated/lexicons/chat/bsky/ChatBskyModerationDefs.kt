// Lexicon: 1, ID: chat.bsky.moderation.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyModerationDefsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.moderation.defs"
}

@Serializable(with = ChatBskyModerationDefsConvoViewKindUnionSerializer::class)
sealed interface ChatBskyModerationDefsConvoViewKindUnion {
    @Serializable
    data class DirectConvo(val value: com.atproto.generated.ChatBskyModerationDefsDirectConvo) : ChatBskyModerationDefsConvoViewKindUnion

    @Serializable
    data class GroupConvo(val value: com.atproto.generated.ChatBskyModerationDefsGroupConvo) : ChatBskyModerationDefsConvoViewKindUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyModerationDefsConvoViewKindUnion
}

object ChatBskyModerationDefsConvoViewKindUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyModerationDefsConvoViewKindUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyModerationDefsConvoViewKindUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyModerationDefsConvoViewKindUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyModerationDefsConvoViewKindUnion.DirectConvo -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyModerationDefsDirectConvo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.moderation.defs#directConvo")
                })
            }
            is ChatBskyModerationDefsConvoViewKindUnion.GroupConvo -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyModerationDefsGroupConvo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.moderation.defs#groupConvo")
                })
            }
            is ChatBskyModerationDefsConvoViewKindUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyModerationDefsConvoViewKindUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.moderation.defs#directConvo" -> ChatBskyModerationDefsConvoViewKindUnion.DirectConvo(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyModerationDefsDirectConvo.serializer(), element)
            )
            "chat.bsky.moderation.defs#groupConvo" -> ChatBskyModerationDefsConvoViewKindUnion.GroupConvo(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyModerationDefsGroupConvo.serializer(), element)
            )
            else -> ChatBskyModerationDefsConvoViewKindUnion.Unexpected(element)
        }
    }
}

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. A view of a conversation for moderation purposes. Unlike chat.bsky.convo.defs#convoView, it does not include viewer-specific data (such as muted, unreadCount, status, lastMessage, lastReaction), since the requester is a moderator and not a member of the conversation. The member list is not included; use chat.bsky.moderation.getConvoMembers to list members.
     */
    @Serializable
    data class ChatBskyModerationDefsConvoView(
        @SerialName("id")
        val id: String,        @SerialName("rev")
        val rev: String,/** Union field that has data specific to different kinds of convos. */        @SerialName("kind")
        val kind: ChatBskyModerationDefsConvoViewKindUnion? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyModerationDefsConvoView"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Data specific to a direct conversation, for moderation purposes.
     */
    @Serializable
    class ChatBskyModerationDefsDirectConvo {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyModerationDefsDirectConvo"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Data specific to a group conversation, for moderation purposes. Unlike chat.bsky.convo.defs#groupConvo, it does not include viewer-specific data (such as unreadJoinRequestCount), since the requester is a moderator and not a member of the conversation.
     */
    @Serializable
    data class ChatBskyModerationDefsGroupConvo(
        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("joinLink")
        val joinLink: ChatBskyGroupDefsJoinLinkView? = null,/** The total number of pending join requests for the group conversation. This information is only visible to the owner and to moderators. Capped at 21. */        @SerialName("joinRequestCount")
        val joinRequestCount: Int,/** The lock status of the conversation. */        @SerialName("lockStatus")
        val lockStatus: ChatBskyConvoDefsConvoLockStatus,/** The total number of members in the group conversation. */        @SerialName("memberCount")
        val memberCount: Int,/** The maximum number of members allowed in the group conversation. */        @SerialName("memberLimit")
        val memberLimit: Int,/** The display name of the group conversation. */        @SerialName("name")
        val name: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyModerationDefsGroupConvo"
        }
    }
