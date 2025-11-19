// Lexicon: 1, ID: chat.bsky.convo.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface MessageinputEmbedUnion {
    @Serializable
    @SerialName("chat.bsky.convo.defs#AppBskyEmbedRecord")
    data class AppBskyEmbedRecord(val value: AppBskyEmbedRecord) : MessageinputEmbedUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : MessageinputEmbedUnion
}

@Serializable
sealed interface MessageviewEmbedUnion {
    @Serializable
    @SerialName("AppBskyEmbedRecord.View")
    data class View(val value: AppBskyEmbedRecord.View) : MessageviewEmbedUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : MessageviewEmbedUnion
}

@Serializable
sealed interface ConvoviewLastmessageUnion {
    @Serializable
    @SerialName("chat.bsky.convo.defs#Messageview")
    data class Messageview(val value: Messageview) : ConvoviewLastmessageUnion

    @Serializable
    @SerialName("chat.bsky.convo.defs#Deletedmessageview")
    data class Deletedmessageview(val value: Deletedmessageview) : ConvoviewLastmessageUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ConvoviewLastmessageUnion
}

@Serializable
sealed interface ConvoviewLastreactionUnion {
    @Serializable
    @SerialName("chat.bsky.convo.defs#Messageandreactionview")
    data class Messageandreactionview(val value: Messageandreactionview) : ConvoviewLastreactionUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ConvoviewLastreactionUnion
}

@Serializable
sealed interface LogcreatemessageMessageUnion {
    @Serializable
    @SerialName("chat.bsky.convo.defs#Messageview")
    data class Messageview(val value: Messageview) : LogcreatemessageMessageUnion

    @Serializable
    @SerialName("chat.bsky.convo.defs#Deletedmessageview")
    data class Deletedmessageview(val value: Deletedmessageview) : LogcreatemessageMessageUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : LogcreatemessageMessageUnion
}

@Serializable
sealed interface LogdeletemessageMessageUnion {
    @Serializable
    @SerialName("chat.bsky.convo.defs#Messageview")
    data class Messageview(val value: Messageview) : LogdeletemessageMessageUnion

    @Serializable
    @SerialName("chat.bsky.convo.defs#Deletedmessageview")
    data class Deletedmessageview(val value: Deletedmessageview) : LogdeletemessageMessageUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : LogdeletemessageMessageUnion
}

@Serializable
sealed interface LogreadmessageMessageUnion {
    @Serializable
    @SerialName("chat.bsky.convo.defs#Messageview")
    data class Messageview(val value: Messageview) : LogreadmessageMessageUnion

    @Serializable
    @SerialName("chat.bsky.convo.defs#Deletedmessageview")
    data class Deletedmessageview(val value: Deletedmessageview) : LogreadmessageMessageUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : LogreadmessageMessageUnion
}

@Serializable
sealed interface LogaddreactionMessageUnion {
    @Serializable
    @SerialName("chat.bsky.convo.defs#Messageview")
    data class Messageview(val value: Messageview) : LogaddreactionMessageUnion

    @Serializable
    @SerialName("chat.bsky.convo.defs#Deletedmessageview")
    data class Deletedmessageview(val value: Deletedmessageview) : LogaddreactionMessageUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : LogaddreactionMessageUnion
}

@Serializable
sealed interface LogremovereactionMessageUnion {
    @Serializable
    @SerialName("chat.bsky.convo.defs#Messageview")
    data class Messageview(val value: Messageview) : LogremovereactionMessageUnion

    @Serializable
    @SerialName("chat.bsky.convo.defs#Deletedmessageview")
    data class Deletedmessageview(val value: Deletedmessageview) : LogremovereactionMessageUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : LogremovereactionMessageUnion
}

object ChatBskyConvoDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.defs"

        @Serializable
    data class Messageref(
        @SerialName("did")
        val did: DID,        @SerialName("convoId")
        val convoId: String,        @SerialName("messageId")
        val messageId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#messageref"
        }
    }

    @Serializable
    data class Messageinput(
        @SerialName("text")
        val text: String,/** Annotations of text (mentions, URLs, hashtags, etc) */        @SerialName("facets")
        val facets: List<AppBskyRichtextFacet>?,        @SerialName("embed")
        val embed: MessageinputEmbedUnion?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#messageinput"
        }
    }

    @Serializable
    data class Messageview(
        @SerialName("id")
        val id: String,        @SerialName("rev")
        val rev: String,        @SerialName("text")
        val text: String,/** Annotations of text (mentions, URLs, hashtags, etc) */        @SerialName("facets")
        val facets: List<AppBskyRichtextFacet>?,        @SerialName("embed")
        val embed: MessageviewEmbedUnion?,/** Reactions to this message, in ascending order of creation time. */        @SerialName("reactions")
        val reactions: List<Reactionview>?,        @SerialName("sender")
        val sender: Messageviewsender,        @SerialName("sentAt")
        val sentAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#messageview"
        }
    }

    @Serializable
    data class Deletedmessageview(
        @SerialName("id")
        val id: String,        @SerialName("rev")
        val rev: String,        @SerialName("sender")
        val sender: Messageviewsender,        @SerialName("sentAt")
        val sentAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#deletedmessageview"
        }
    }

    @Serializable
    data class Messageviewsender(
        @SerialName("did")
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#messageviewsender"
        }
    }

    @Serializable
    data class Reactionview(
        @SerialName("value")
        val value: String,        @SerialName("sender")
        val sender: Reactionviewsender,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#reactionview"
        }
    }

    @Serializable
    data class Reactionviewsender(
        @SerialName("did")
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#reactionviewsender"
        }
    }

    @Serializable
    data class Messageandreactionview(
        @SerialName("message")
        val message: Messageview,        @SerialName("reaction")
        val reaction: Reactionview    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#messageandreactionview"
        }
    }

    @Serializable
    data class Convoview(
        @SerialName("id")
        val id: String,        @SerialName("rev")
        val rev: String,        @SerialName("members")
        val members: List<ChatBskyActorDefs.Profileviewbasic>,        @SerialName("lastMessage")
        val lastMessage: ConvoviewLastmessageUnion?,        @SerialName("lastReaction")
        val lastReaction: ConvoviewLastreactionUnion?,        @SerialName("muted")
        val muted: Boolean,        @SerialName("status")
        val status: String?,        @SerialName("unreadCount")
        val unreadCount: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#convoview"
        }
    }

    @Serializable
    data class Logbeginconvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#logbeginconvo"
        }
    }

    @Serializable
    data class Logacceptconvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#logacceptconvo"
        }
    }

    @Serializable
    data class Logleaveconvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#logleaveconvo"
        }
    }

    @Serializable
    data class Logmuteconvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#logmuteconvo"
        }
    }

    @Serializable
    data class Logunmuteconvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#logunmuteconvo"
        }
    }

    @Serializable
    data class Logcreatemessage(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: LogcreatemessageMessageUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#logcreatemessage"
        }
    }

    @Serializable
    data class Logdeletemessage(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: LogdeletemessageMessageUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#logdeletemessage"
        }
    }

    @Serializable
    data class Logreadmessage(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: LogreadmessageMessageUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#logreadmessage"
        }
    }

    @Serializable
    data class Logaddreaction(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: LogaddreactionMessageUnion,        @SerialName("reaction")
        val reaction: Reactionview    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#logaddreaction"
        }
    }

    @Serializable
    data class Logremovereaction(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: LogremovereactionMessageUnion,        @SerialName("reaction")
        val reaction: Reactionview    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#logremovereaction"
        }
    }

}
