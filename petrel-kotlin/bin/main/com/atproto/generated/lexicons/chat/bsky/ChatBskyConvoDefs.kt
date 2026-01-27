// Lexicon: 1, ID: chat.bsky.convo.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyConvoDefsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.defs"
}

@Serializable
sealed interface ChatBskyConvoDefsMessageInputEmbedUnion {
    @Serializable
    @SerialName("chat.bsky.convo.defs#AppBskyEmbedRecord")
    data class AppBskyEmbedRecord(val value: AppBskyEmbedRecord) : ChatBskyConvoDefsMessageInputEmbedUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsMessageInputEmbedUnion
}

@Serializable
sealed interface ChatBskyConvoDefsMessageViewEmbedUnion {
    @Serializable
    @SerialName("chat.bsky.convo.defs#AppBskyEmbedRecordView")
    data class AppBskyEmbedRecordView(val value: AppBskyEmbedRecordView) : ChatBskyConvoDefsMessageViewEmbedUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsMessageViewEmbedUnion
}

@Serializable
sealed interface ChatBskyConvoDefsConvoViewLastMessageUnion {
    @Serializable
    @SerialName("chat.bsky.convo.defs#ChatBskyConvoDefsMessageView")
    data class ChatBskyConvoDefsMessageView(val value: ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsConvoViewLastMessageUnion

    @Serializable
    @SerialName("chat.bsky.convo.defs#ChatBskyConvoDefsDeletedMessageView")
    data class ChatBskyConvoDefsDeletedMessageView(val value: ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsConvoViewLastMessageUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsConvoViewLastMessageUnion
}

@Serializable
sealed interface ChatBskyConvoDefsConvoViewLastReactionUnion {
    @Serializable
    @SerialName("chat.bsky.convo.defs#ChatBskyConvoDefsMessageAndReactionView")
    data class ChatBskyConvoDefsMessageAndReactionView(val value: ChatBskyConvoDefsMessageAndReactionView) : ChatBskyConvoDefsConvoViewLastReactionUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsConvoViewLastReactionUnion
}

@Serializable
sealed interface ChatBskyConvoDefsLogCreateMessageMessageUnion {
    @Serializable
    @SerialName("chat.bsky.convo.defs#ChatBskyConvoDefsMessageView")
    data class ChatBskyConvoDefsMessageView(val value: ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsLogCreateMessageMessageUnion

    @Serializable
    @SerialName("chat.bsky.convo.defs#ChatBskyConvoDefsDeletedMessageView")
    data class ChatBskyConvoDefsDeletedMessageView(val value: ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsLogCreateMessageMessageUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsLogCreateMessageMessageUnion
}

@Serializable
sealed interface ChatBskyConvoDefsLogDeleteMessageMessageUnion {
    @Serializable
    @SerialName("chat.bsky.convo.defs#ChatBskyConvoDefsMessageView")
    data class ChatBskyConvoDefsMessageView(val value: ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsLogDeleteMessageMessageUnion

    @Serializable
    @SerialName("chat.bsky.convo.defs#ChatBskyConvoDefsDeletedMessageView")
    data class ChatBskyConvoDefsDeletedMessageView(val value: ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsLogDeleteMessageMessageUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsLogDeleteMessageMessageUnion
}

@Serializable
sealed interface ChatBskyConvoDefsLogReadMessageMessageUnion {
    @Serializable
    @SerialName("chat.bsky.convo.defs#ChatBskyConvoDefsMessageView")
    data class ChatBskyConvoDefsMessageView(val value: ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsLogReadMessageMessageUnion

    @Serializable
    @SerialName("chat.bsky.convo.defs#ChatBskyConvoDefsDeletedMessageView")
    data class ChatBskyConvoDefsDeletedMessageView(val value: ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsLogReadMessageMessageUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsLogReadMessageMessageUnion
}

@Serializable
sealed interface ChatBskyConvoDefsLogAddReactionMessageUnion {
    @Serializable
    @SerialName("chat.bsky.convo.defs#ChatBskyConvoDefsMessageView")
    data class ChatBskyConvoDefsMessageView(val value: ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsLogAddReactionMessageUnion

    @Serializable
    @SerialName("chat.bsky.convo.defs#ChatBskyConvoDefsDeletedMessageView")
    data class ChatBskyConvoDefsDeletedMessageView(val value: ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsLogAddReactionMessageUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsLogAddReactionMessageUnion
}

@Serializable
sealed interface ChatBskyConvoDefsLogRemoveReactionMessageUnion {
    @Serializable
    @SerialName("chat.bsky.convo.defs#ChatBskyConvoDefsMessageView")
    data class ChatBskyConvoDefsMessageView(val value: ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsLogRemoveReactionMessageUnion

    @Serializable
    @SerialName("chat.bsky.convo.defs#ChatBskyConvoDefsDeletedMessageView")
    data class ChatBskyConvoDefsDeletedMessageView(val value: ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsLogRemoveReactionMessageUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsLogRemoveReactionMessageUnion
}

    @Serializable
    data class ChatBskyConvoDefsMessageRef(
        @SerialName("did")
        val did: DID,        @SerialName("convoId")
        val convoId: String,        @SerialName("messageId")
        val messageId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsMessageRef"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsMessageInput(
        @SerialName("text")
        val text: String,/** Annotations of text (mentions, URLs, hashtags, etc) */        @SerialName("facets")
        val facets: List<AppBskyRichtextFacet>?,        @SerialName("embed")
        val embed: ChatBskyConvoDefsMessageInputEmbedUnion?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsMessageInput"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsMessageView(
        @SerialName("id")
        val id: String,        @SerialName("rev")
        val rev: String,        @SerialName("text")
        val text: String,/** Annotations of text (mentions, URLs, hashtags, etc) */        @SerialName("facets")
        val facets: List<AppBskyRichtextFacet>?,        @SerialName("embed")
        val embed: ChatBskyConvoDefsMessageViewEmbedUnion?,/** Reactions to this message, in ascending order of creation time. */        @SerialName("reactions")
        val reactions: List<ChatBskyConvoDefsReactionView>?,        @SerialName("sender")
        val sender: ChatBskyConvoDefsMessageViewSender,        @SerialName("sentAt")
        val sentAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsMessageView"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsDeletedMessageView(
        @SerialName("id")
        val id: String,        @SerialName("rev")
        val rev: String,        @SerialName("sender")
        val sender: ChatBskyConvoDefsMessageViewSender,        @SerialName("sentAt")
        val sentAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsDeletedMessageView"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsMessageViewSender(
        @SerialName("did")
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsMessageViewSender"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsReactionView(
        @SerialName("value")
        val value: String,        @SerialName("sender")
        val sender: ChatBskyConvoDefsReactionViewSender,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsReactionView"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsReactionViewSender(
        @SerialName("did")
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsReactionViewSender"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsMessageAndReactionView(
        @SerialName("message")
        val message: ChatBskyConvoDefsMessageView,        @SerialName("reaction")
        val reaction: ChatBskyConvoDefsReactionView    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsMessageAndReactionView"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsConvoView(
        @SerialName("id")
        val id: String,        @SerialName("rev")
        val rev: String,        @SerialName("members")
        val members: List<ChatBskyActorDefsProfileViewBasic>,        @SerialName("lastMessage")
        val lastMessage: ChatBskyConvoDefsConvoViewLastMessageUnion?,        @SerialName("lastReaction")
        val lastReaction: ChatBskyConvoDefsConvoViewLastReactionUnion?,        @SerialName("muted")
        val muted: Boolean,        @SerialName("status")
        val status: String?,        @SerialName("unreadCount")
        val unreadCount: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsConvoView"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsLogBeginConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogBeginConvo"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsLogAcceptConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogAcceptConvo"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsLogLeaveConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogLeaveConvo"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsLogMuteConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogMuteConvo"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsLogUnmuteConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogUnmuteConvo"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsLogCreateMessage(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsLogCreateMessageMessageUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogCreateMessage"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsLogDeleteMessage(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsLogDeleteMessageMessageUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogDeleteMessage"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsLogReadMessage(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsLogReadMessageMessageUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogReadMessage"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsLogAddReaction(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsLogAddReactionMessageUnion,        @SerialName("reaction")
        val reaction: ChatBskyConvoDefsReactionView    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogAddReaction"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsLogRemoveReaction(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsLogRemoveReactionMessageUnion,        @SerialName("reaction")
        val reaction: ChatBskyConvoDefsReactionView    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogRemoveReaction"
        }
    }
