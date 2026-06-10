// Lexicon: 1, ID: chat.bsky.moderation.subscribeModEvents
// Subscribe to stream of chat events targeted to moderation. Private endpoint.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyModerationSubscribeModEventsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.moderation.subscribeModEvents"
}

@Serializable(with = ChatBskyModerationSubscribeModEventsMessageUnionSerializer::class)
sealed interface ChatBskyModerationSubscribeModEventsMessageUnion {
    @Serializable
    data class EventConvoFirstMessage(val value: com.atproto.generated.ChatBskyModerationSubscribeModEventsEventConvoFirstMessage) : ChatBskyModerationSubscribeModEventsMessageUnion

    @Serializable
    data class EventGroupChatCreated(val value: com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatCreated) : ChatBskyModerationSubscribeModEventsMessageUnion

    @Serializable
    data class EventGroupChatMemberAdded(val value: com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatMemberAdded) : ChatBskyModerationSubscribeModEventsMessageUnion

    @Serializable
    data class EventGroupChatMemberJoined(val value: com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatMemberJoined) : ChatBskyModerationSubscribeModEventsMessageUnion

    @Serializable
    data class EventGroupChatJoinRequest(val value: com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatJoinRequest) : ChatBskyModerationSubscribeModEventsMessageUnion

    @Serializable
    data class EventGroupChatJoinRequestApproved(val value: com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatJoinRequestApproved) : ChatBskyModerationSubscribeModEventsMessageUnion

    @Serializable
    data class EventGroupChatJoinRequestRejected(val value: com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatJoinRequestRejected) : ChatBskyModerationSubscribeModEventsMessageUnion

    @Serializable
    data class EventChatAccepted(val value: com.atproto.generated.ChatBskyModerationSubscribeModEventsEventChatAccepted) : ChatBskyModerationSubscribeModEventsMessageUnion

    @Serializable
    data class EventGroupChatMemberLeft(val value: com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatMemberLeft) : ChatBskyModerationSubscribeModEventsMessageUnion

    @Serializable
    data class EventGroupChatUpdated(val value: com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatUpdated) : ChatBskyModerationSubscribeModEventsMessageUnion

    @Serializable
    data class EventRateLimitExceeded(val value: com.atproto.generated.ChatBskyModerationSubscribeModEventsEventRateLimitExceeded) : ChatBskyModerationSubscribeModEventsMessageUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyModerationSubscribeModEventsMessageUnion
}

object ChatBskyModerationSubscribeModEventsMessageUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyModerationSubscribeModEventsMessageUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyModerationSubscribeModEventsMessageUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyModerationSubscribeModEventsMessageUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyModerationSubscribeModEventsMessageUnion.EventConvoFirstMessage -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventConvoFirstMessage.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.moderation.subscribeModEvents#eventConvoFirstMessage")
                })
            }
            is ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatCreated -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatCreated.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.moderation.subscribeModEvents#eventGroupChatCreated")
                })
            }
            is ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatMemberAdded -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatMemberAdded.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.moderation.subscribeModEvents#eventGroupChatMemberAdded")
                })
            }
            is ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatMemberJoined -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatMemberJoined.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.moderation.subscribeModEvents#eventGroupChatMemberJoined")
                })
            }
            is ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatJoinRequest -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatJoinRequest.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.moderation.subscribeModEvents#eventGroupChatJoinRequest")
                })
            }
            is ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatJoinRequestApproved -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatJoinRequestApproved.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.moderation.subscribeModEvents#eventGroupChatJoinRequestApproved")
                })
            }
            is ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatJoinRequestRejected -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatJoinRequestRejected.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.moderation.subscribeModEvents#eventGroupChatJoinRequestRejected")
                })
            }
            is ChatBskyModerationSubscribeModEventsMessageUnion.EventChatAccepted -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventChatAccepted.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.moderation.subscribeModEvents#eventChatAccepted")
                })
            }
            is ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatMemberLeft -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatMemberLeft.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.moderation.subscribeModEvents#eventGroupChatMemberLeft")
                })
            }
            is ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatUpdated -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatUpdated.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.moderation.subscribeModEvents#eventGroupChatUpdated")
                })
            }
            is ChatBskyModerationSubscribeModEventsMessageUnion.EventRateLimitExceeded -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventRateLimitExceeded.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.moderation.subscribeModEvents#eventRateLimitExceeded")
                })
            }
            is ChatBskyModerationSubscribeModEventsMessageUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyModerationSubscribeModEventsMessageUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.moderation.subscribeModEvents#eventConvoFirstMessage" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventConvoFirstMessage(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventConvoFirstMessage.serializer(), element)
            )
            "chat.bsky.moderation.subscribeModEvents#eventGroupChatCreated" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatCreated(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatCreated.serializer(), element)
            )
            "chat.bsky.moderation.subscribeModEvents#eventGroupChatMemberAdded" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatMemberAdded(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatMemberAdded.serializer(), element)
            )
            "chat.bsky.moderation.subscribeModEvents#eventGroupChatMemberJoined" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatMemberJoined(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatMemberJoined.serializer(), element)
            )
            "chat.bsky.moderation.subscribeModEvents#eventGroupChatJoinRequest" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatJoinRequest(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatJoinRequest.serializer(), element)
            )
            "chat.bsky.moderation.subscribeModEvents#eventGroupChatJoinRequestApproved" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatJoinRequestApproved(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatJoinRequestApproved.serializer(), element)
            )
            "chat.bsky.moderation.subscribeModEvents#eventGroupChatJoinRequestRejected" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatJoinRequestRejected(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatJoinRequestRejected.serializer(), element)
            )
            "chat.bsky.moderation.subscribeModEvents#eventChatAccepted" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventChatAccepted(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventChatAccepted.serializer(), element)
            )
            "chat.bsky.moderation.subscribeModEvents#eventGroupChatMemberLeft" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatMemberLeft(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatMemberLeft.serializer(), element)
            )
            "chat.bsky.moderation.subscribeModEvents#eventGroupChatUpdated" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatUpdated(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatUpdated.serializer(), element)
            )
            "chat.bsky.moderation.subscribeModEvents#eventRateLimitExceeded" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventRateLimitExceeded(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventRateLimitExceeded.serializer(), element)
            )
            else -> ChatBskyModerationSubscribeModEventsMessageUnion.Unexpected(element)
        }
    }
}

    /**
     * Fired when the first message was sent on a convo.
     */
    @Serializable
    data class ChatBskyModerationSubscribeModEventsEventConvoFirstMessage(
        @SerialName("convoId")
        val convoId: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("messageId")
        val messageId: String? = null,/** The list of DIDs message recipients. Does not include the sender, which is in the `user` field */        @SerialName("recipients")
        val recipients: List<DID>,        @SerialName("rev")
        val rev: String,/** The DID of the message author. */        @SerialName("user")
        val user: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyModerationSubscribeModEventsEventConvoFirstMessage"
        }
    }

    /**
     * Fire when a group chat is created.
     */
    @Serializable
    data class ChatBskyModerationSubscribeModEventsEventGroupChatCreated(
/** The DID of the actor performing the action. For this event, same as ownerDid. */        @SerialName("actorDid")
        val actorDid: DID,/** When the group was originally created. */        @SerialName("convoCreatedAt")
        val convoCreatedAt: ATProtocolDate,        @SerialName("convoId")
        val convoId: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** Current member count at the time of the event. */        @SerialName("groupMemberCount")
        val groupMemberCount: Int,/** The name set at creation time. */        @SerialName("groupName")
        val groupName: String,/** DIDs of everyone added at creation time. */        @SerialName("initialMemberDids")
        val initialMemberDids: List<DID>,/** The DID of the group chat owner. */        @SerialName("ownerDid")
        val ownerDid: DID,        @SerialName("rev")
        val rev: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyModerationSubscribeModEventsEventGroupChatCreated"
        }
    }

    /**
     * Fired when a member is added to a group chat. Note that members are added in the 'request' state.
     */
    @Serializable
    data class ChatBskyModerationSubscribeModEventsEventGroupChatMemberAdded(
/** The DID of the actor performing the action. For this event, same as ownerDid. */        @SerialName("actorDid")
        val actorDid: DID,/** When the group was originally created. */        @SerialName("convoCreatedAt")
        val convoCreatedAt: ATProtocolDate,        @SerialName("convoId")
        val convoId: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** Current member count at the time of the event. */        @SerialName("groupMemberCount")
        val groupMemberCount: Int,        @SerialName("groupName")
        val groupName: String,/** The DID of the group chat owner. */        @SerialName("ownerDid")
        val ownerDid: DID,/** The number of members who have not yet accepted the convo. */        @SerialName("requestMembersCount")
        val requestMembersCount: Int,        @SerialName("rev")
        val rev: String,/** The DID of the member who was added. */        @SerialName("subjectDid")
        val subjectDid: DID,/** Whether the added member follows the group owner. */        @SerialName("subjectFollowsOwner")
        val subjectFollowsOwner: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyModerationSubscribeModEventsEventGroupChatMemberAdded"
        }
    }

    /**
     * Fired when a member joins a group chat via an join link that does not require approval.
     */
    @Serializable
    data class ChatBskyModerationSubscribeModEventsEventGroupChatMemberJoined(
/** The DID of the person joining. */        @SerialName("actorDid")
        val actorDid: DID,/** When the group was originally created. */        @SerialName("convoCreatedAt")
        val convoCreatedAt: ATProtocolDate,        @SerialName("convoId")
        val convoId: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** Current member count at the time of the event. */        @SerialName("groupMemberCount")
        val groupMemberCount: Int,        @SerialName("groupName")
        val groupName: String,/** The code of the join link used to join. */        @SerialName("joinLinkCode")
        val joinLinkCode: String,/** The DID of the group chat owner. */        @SerialName("ownerDid")
        val ownerDid: DID,        @SerialName("rev")
        val rev: String,/** Whether the joining member follows the group owner. */        @SerialName("subjectFollowsOwner")
        val subjectFollowsOwner: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyModerationSubscribeModEventsEventGroupChatMemberJoined"
        }
    }

    /**
     * Fired when a user requests to join a group chat via an join link that requires approval.
     */
    @Serializable
    data class ChatBskyModerationSubscribeModEventsEventGroupChatJoinRequest(
/** The DID of the person requesting to join. */        @SerialName("actorDid")
        val actorDid: DID,/** When the group was originally created. */        @SerialName("convoCreatedAt")
        val convoCreatedAt: ATProtocolDate,        @SerialName("convoId")
        val convoId: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** Current member count at the time of the event. */        @SerialName("groupMemberCount")
        val groupMemberCount: Int,        @SerialName("groupName")
        val groupName: String,/** The code of the join link used to request joining. */        @SerialName("joinLinkCode")
        val joinLinkCode: String,/** The DID of the group chat owner. */        @SerialName("ownerDid")
        val ownerDid: DID,        @SerialName("rev")
        val rev: String,/** Whether the requesting member follows the group owner. */        @SerialName("subjectFollowsOwner")
        val subjectFollowsOwner: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyModerationSubscribeModEventsEventGroupChatJoinRequest"
        }
    }

    /**
     * Fired when a join request is approved by the group owner.
     */
    @Serializable
    data class ChatBskyModerationSubscribeModEventsEventGroupChatJoinRequestApproved(
/** The DID of the owner approving the request. */        @SerialName("actorDid")
        val actorDid: DID,/** When the group was originally created. */        @SerialName("convoCreatedAt")
        val convoCreatedAt: ATProtocolDate,        @SerialName("convoId")
        val convoId: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** Current member count at the time of the event. */        @SerialName("groupMemberCount")
        val groupMemberCount: Int,        @SerialName("groupName")
        val groupName: String,/** The DID of the group chat owner. */        @SerialName("ownerDid")
        val ownerDid: DID,        @SerialName("rev")
        val rev: String,/** The DID of the member whose request was approved. */        @SerialName("subjectDid")
        val subjectDid: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyModerationSubscribeModEventsEventGroupChatJoinRequestApproved"
        }
    }

    /**
     * Fired when a join request is rejected by the group owner.
     */
    @Serializable
    data class ChatBskyModerationSubscribeModEventsEventGroupChatJoinRequestRejected(
/** The DID of the owner rejecting the request. */        @SerialName("actorDid")
        val actorDid: DID,/** When the group was originally created. */        @SerialName("convoCreatedAt")
        val convoCreatedAt: ATProtocolDate,        @SerialName("convoId")
        val convoId: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** Current member count at the time of the event. */        @SerialName("groupMemberCount")
        val groupMemberCount: Int,        @SerialName("groupName")
        val groupName: String,/** The DID of the group chat owner. */        @SerialName("ownerDid")
        val ownerDid: DID,        @SerialName("rev")
        val rev: String,/** The DID of the member whose request was rejected. */        @SerialName("subjectDid")
        val subjectDid: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyModerationSubscribeModEventsEventGroupChatJoinRequestRejected"
        }
    }

    /**
     * Fired when a user accepts a chat convo, either explicitly or by sending a message.
     */
    @Serializable
    data class ChatBskyModerationSubscribeModEventsEventChatAccepted(
/** The DID of the person accepting the convo. */        @SerialName("actorDid")
        val actorDid: DID,/** When the convo was originally created. */        @SerialName("convoCreatedAt")
        val convoCreatedAt: ATProtocolDate,        @SerialName("convoId")
        val convoId: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** Current member count at the time of the event. Only present for group convos. */        @SerialName("groupMemberCount")
        val groupMemberCount: Int? = null,/** The name of the group chat. Only present for group convos. */        @SerialName("groupName")
        val groupName: String? = null,/** How the convo was accepted. */        @SerialName("method")
        val method: String,/** The DID of the group chat owner. Only present for group convos. */        @SerialName("ownerDid")
        val ownerDid: DID? = null,        @SerialName("rev")
        val rev: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyModerationSubscribeModEventsEventChatAccepted"
        }
    }

    /**
     * Fired when a member leaves or is removed from a group chat.
     */
    @Serializable
    data class ChatBskyModerationSubscribeModEventsEventGroupChatMemberLeft(
/** The DID of the actor. For voluntary: the person leaving. For kicked: the owner. */        @SerialName("actorDid")
        val actorDid: DID,/** When the group was originally created. */        @SerialName("convoCreatedAt")
        val convoCreatedAt: ATProtocolDate,        @SerialName("convoId")
        val convoId: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** Current member count at the time of the event. */        @SerialName("groupMemberCount")
        val groupMemberCount: Int,        @SerialName("groupName")
        val groupName: String,/** How the member left. */        @SerialName("leaveMethod")
        val leaveMethod: String,/** The DID of the group chat owner. */        @SerialName("ownerDid")
        val ownerDid: DID,        @SerialName("rev")
        val rev: String,/** The DID of the member who left or was removed. */        @SerialName("subjectDid")
        val subjectDid: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyModerationSubscribeModEventsEventGroupChatMemberLeft"
        }
    }

    /**
     * Fired when a group chat's metadata or status changes.
     */
    @Serializable
    data class ChatBskyModerationSubscribeModEventsEventGroupChatUpdated(
/** The DID of the actor performing the action (the owner). */        @SerialName("actorDid")
        val actorDid: DID,/** When the group was originally created. */        @SerialName("convoCreatedAt")
        val convoCreatedAt: ATProtocolDate,        @SerialName("convoId")
        val convoId: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** Current member count at the time of the event. */        @SerialName("groupMemberCount")
        val groupMemberCount: Int,/** Current group name. */        @SerialName("groupName")
        val groupName: String,/** The code of the join link. Only present when updateType is join-link-related. */        @SerialName("joinLinkCode")
        val joinLinkCode: String? = null,/** Whether the join link is restricted to followers of the owner. Only present when updateType is join-link-related. */        @SerialName("joinLinkFollowersOnly")
        val joinLinkFollowersOnly: Boolean? = null,/** Whether the join link requires owner approval to join. Only present when updateType is join-link-related. */        @SerialName("joinLinkRequiresApproval")
        val joinLinkRequiresApproval: Boolean? = null,/** Why the group was locked. Only present when updateType is 'locked'. */        @SerialName("lockReason")
        val lockReason: String? = null,/** The new group name. Only present when updateType is 'name_changed'. */        @SerialName("newName")
        val newName: String? = null,/** The previous group name. Only present when updateType is 'name_changed'. */        @SerialName("oldName")
        val oldName: String? = null,/** The DID of the group chat owner. */        @SerialName("ownerDid")
        val ownerDid: DID,        @SerialName("rev")
        val rev: String,/** What changed. */        @SerialName("updateType")
        val updateType: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyModerationSubscribeModEventsEventGroupChatUpdated"
        }
    }

    /**
     * Fired when a user exceeds a rate limit.
     */
    @Serializable
    data class ChatBskyModerationSubscribeModEventsEventRateLimitExceeded(
/** The DID of the user who hit the rate limit. */        @SerialName("actorDid")
        val actorDid: DID,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** The NSID of the endpoint that was rate limited. */        @SerialName("endpoint")
        val endpoint: String,        @SerialName("rev")
        val rev: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyModerationSubscribeModEventsEventRateLimitExceeded"
        }
    }

@Serializable
    data class ChatBskyModerationSubscribeModEventsParameters(
// The last known event seq number to backfill from. Use '2222222222222' to backfill from the beginning. Don't specify a cursor to listen only for new events.        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    class ChatBskyModerationSubscribeModEventsMessage

sealed class ChatBskyModerationSubscribeModEventsError(val name: String, val description: String?) {
        object FutureCursor: ChatBskyModerationSubscribeModEventsError("FutureCursor", "")
        object ConsumerTooSlow: ChatBskyModerationSubscribeModEventsError("ConsumerTooSlow", "If the consumer of the stream can not keep up with events, and a backlog gets too large, the server will drop the connection.")
    }

/**
 * Synthetic variants augmenting the generated ChatBskyModerationSubscribeModEventsMessageUnion sealed interface.
 *
 * `Error` surfaces ATProto `op == -1` server error frames; `Unexpected` wraps
 * frames whose header tag did not match any known variant (e.g. new event types
 * added server-side before client regen). Kept as extensions so the lexicon-
 * driven sealed interface stays mechanically faithful to the schema.
 */
data class ChatBskyModerationSubscribeModEventsMessageUnionError(val name: String, val message: String?) : ChatBskyModerationSubscribeModEventsMessageUnion
data class ChatBskyModerationSubscribeModEventsMessageUnionUnexpected(val type: String, val payload: kotlinx.serialization.json.JsonObject) : ChatBskyModerationSubscribeModEventsMessageUnion

/**
 * Subscribe to stream of chat events targeted to moderation. Private endpoint.
 *
 * Endpoint: chat.bsky.moderation.subscribeModEvents
 *
 * The returned [kotlinx.coroutines.flow.Flow] completes (or throws) when the
 * underlying WebSocket disconnects. Reconnect / cursor-resume is the caller's
 * responsibility — wrap in `retryWhen { ... }` with backoff as needed.
 */
fun ATProtoClient.Chat.Bsky.Moderation.subscribeModEvents(
parameters: ChatBskyModerationSubscribeModEventsParameters? = null,
hostOverride: String? = null,
    websocketClient: io.ktor.client.HttpClient? = null,
): kotlinx.coroutines.flow.Flow<ChatBskyModerationSubscribeModEventsMessageUnion> = kotlinx.coroutines.flow.flow {
    val endpoint = "chat.bsky.moderation.subscribeModEvents"
    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?collections=a&collections=b`).
    val queryItems = parameters?.toQueryItems().orEmpty()

    client.openSubscription(endpoint, queryItems, hostOverride, websocketClient) { frame ->
        val decoded: ChatBskyModerationSubscribeModEventsMessageUnion = when (frame) {
            is com.atproto.runtime.subscription.CborFrame.Error ->
                ChatBskyModerationSubscribeModEventsMessageUnionError(frame.name, frame.message)
            is com.atproto.runtime.subscription.CborFrame.Message -> {
                val json = kotlinx.serialization.json.Json {
                    ignoreUnknownKeys = true
                    isLenient = true
                }
                try {
                    when (frame.header.t) {
                        "#eventConvoFirstMessage" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventConvoFirstMessage(
                            json.decodeFromJsonElement(
                                com.atproto.generated.ChatBskyModerationSubscribeModEventsEventConvoFirstMessage.serializer(),
                                frame.payload
                            )
                        )
                        "#eventGroupChatCreated" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatCreated(
                            json.decodeFromJsonElement(
                                com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatCreated.serializer(),
                                frame.payload
                            )
                        )
                        "#eventGroupChatMemberAdded" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatMemberAdded(
                            json.decodeFromJsonElement(
                                com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatMemberAdded.serializer(),
                                frame.payload
                            )
                        )
                        "#eventGroupChatMemberJoined" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatMemberJoined(
                            json.decodeFromJsonElement(
                                com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatMemberJoined.serializer(),
                                frame.payload
                            )
                        )
                        "#eventGroupChatJoinRequest" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatJoinRequest(
                            json.decodeFromJsonElement(
                                com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatJoinRequest.serializer(),
                                frame.payload
                            )
                        )
                        "#eventGroupChatJoinRequestApproved" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatJoinRequestApproved(
                            json.decodeFromJsonElement(
                                com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatJoinRequestApproved.serializer(),
                                frame.payload
                            )
                        )
                        "#eventGroupChatJoinRequestRejected" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatJoinRequestRejected(
                            json.decodeFromJsonElement(
                                com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatJoinRequestRejected.serializer(),
                                frame.payload
                            )
                        )
                        "#eventChatAccepted" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventChatAccepted(
                            json.decodeFromJsonElement(
                                com.atproto.generated.ChatBskyModerationSubscribeModEventsEventChatAccepted.serializer(),
                                frame.payload
                            )
                        )
                        "#eventGroupChatMemberLeft" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatMemberLeft(
                            json.decodeFromJsonElement(
                                com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatMemberLeft.serializer(),
                                frame.payload
                            )
                        )
                        "#eventGroupChatUpdated" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventGroupChatUpdated(
                            json.decodeFromJsonElement(
                                com.atproto.generated.ChatBskyModerationSubscribeModEventsEventGroupChatUpdated.serializer(),
                                frame.payload
                            )
                        )
                        "#eventRateLimitExceeded" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventRateLimitExceeded(
                            json.decodeFromJsonElement(
                                com.atproto.generated.ChatBskyModerationSubscribeModEventsEventRateLimitExceeded.serializer(),
                                frame.payload
                            )
                        )
                        else -> ChatBskyModerationSubscribeModEventsMessageUnionUnexpected(frame.header.t, frame.payload)
                    }
                } catch (e: Throwable) {
                    ChatBskyModerationSubscribeModEventsMessageUnionUnexpected(frame.header.t, frame.payload)
                }
            }
        }
        emit(decoded)
    }
}
