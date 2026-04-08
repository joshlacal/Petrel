// Lexicon: 1, ID: blue.catbird.mls.message.defs
// Definitions for encrypted MLS message payload structure. The ciphertext bytes in messageView decrypt to the payloadView structure defined here. NOTE: Since payloads are end-to-end encrypted, client implementations may use simplified JSON encodings (e.g., without $type fields) as the server never sees the plaintext.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsMessageDefsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.message.defs"
}

@Serializable
sealed interface BlueCatbirdMlsMessageDefsPayloadViewEmbedUnion {
    @Serializable
    @SerialName("blue.catbird.mls.message.defs#BlueCatbirdMlsMessageDefsRecordEmbed")
    data class BlueCatbirdMlsMessageDefsRecordEmbed(val value: BlueCatbirdMlsMessageDefsRecordEmbed) : BlueCatbirdMlsMessageDefsPayloadViewEmbedUnion

    @Serializable
    @SerialName("blue.catbird.mls.message.defs#BlueCatbirdMlsMessageDefsLinkEmbed")
    data class BlueCatbirdMlsMessageDefsLinkEmbed(val value: BlueCatbirdMlsMessageDefsLinkEmbed) : BlueCatbirdMlsMessageDefsPayloadViewEmbedUnion

    @Serializable
    @SerialName("blue.catbird.mls.message.defs#BlueCatbirdMlsMessageDefsGifEmbed")
    data class BlueCatbirdMlsMessageDefsGifEmbed(val value: BlueCatbirdMlsMessageDefsGifEmbed) : BlueCatbirdMlsMessageDefsPayloadViewEmbedUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : BlueCatbirdMlsMessageDefsPayloadViewEmbedUnion
}

    /**
     * Decrypted message payload structure (what's inside the encrypted ciphertext). This is what clients decrypt from the ciphertext bytes.
     */
    @Serializable
    data class BlueCatbirdMlsMessageDefsPayloadView(
/** Payload format version for future compatibility. Current version is 1. */        @SerialName("version")
        val version: Int,/** Message type discriminator */        @SerialName("messageType")
        val messageType: String,/** Message text content (for messageType: text) */        @SerialName("text")
        val text: String?,/** Optional rich media embed (record, link, or GIF). Clients can add new types in future versions. */        @SerialName("embed")
        val embed: BlueCatbirdMlsMessageDefsPayloadViewEmbedUnion?,/** Admin roster update (for messageType: adminRoster) */        @SerialName("adminRoster")
        val adminRoster: BlueCatbirdMlsMessageDefsAdminRoster?,/** Admin action notification (for messageType: adminAction) */        @SerialName("adminAction")
        val adminAction: BlueCatbirdMlsMessageDefsAdminAction?,/** Reaction payload (for messageType: reaction) */        @SerialName("reaction")
        val reaction: BlueCatbirdMlsMessageDefsReactionPayload?,/** Read receipt payload (for messageType: readReceipt) */        @SerialName("readReceipt")
        val readReceipt: BlueCatbirdMlsMessageDefsReadReceiptPayload?,/** Typing indicator payload (for messageType: typing) */        @SerialName("typing")
        val typing: BlueCatbirdMlsMessageDefsTypingPayload?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsMessageDefsPayloadView"
        }
    }

    /**
     * Bluesky record embed (quote post). References an AT Protocol record by URI.
     */
    @Serializable
    data class BlueCatbirdMlsMessageDefsRecordEmbed(
/** AT-URI of the referenced record (e.g., at://did:plc:xyz/app.bsky.feed.post/abc123) */        @SerialName("uri")
        val uri: ATProtocolURI,/** CID of the record for verification */        @SerialName("cid")
        val cid: CID?,/** DID of the record author */        @SerialName("authorDid")
        val authorDid: DID,/** Preview text (first line or excerpt) from the record */        @SerialName("previewText")
        val previewText: String?,/** Timestamp when the record was created */        @SerialName("createdAt")
        val createdAt: ATProtocolDate?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsMessageDefsRecordEmbed"
        }
    }

    /**
     * External link preview with metadata
     */
    @Serializable
    data class BlueCatbirdMlsMessageDefsLinkEmbed(
/** Full URL of the external link */        @SerialName("url")
        val url: URI,/** Page title from Open Graph or meta tags */        @SerialName("title")
        val title: String?,/** Page description from Open Graph or meta tags */        @SerialName("description")
        val description: String?,/** Thumbnail/preview image URL */        @SerialName("thumbnailURL")
        val thumbnailURL: URI?,/** Canonical domain (e.g., 'bsky.app', 'github.com') */        @SerialName("domain")
        val domain: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsMessageDefsLinkEmbed"
        }
    }

    /**
     * Tenor GIF embed (converted to MP4 for efficient playback)
     */
    @Serializable
    data class BlueCatbirdMlsMessageDefsGifEmbed(
/** Original Tenor GIF URL (e.g., https://tenor.com/view/...) */        @SerialName("tenorURL")
        val tenorURL: URI,/** MP4 video URL for efficient playback */        @SerialName("mp4URL")
        val mp4URL: URI,/** GIF title or description from Tenor */        @SerialName("title")
        val title: String?,/** Thumbnail image URL for preview */        @SerialName("thumbnailURL")
        val thumbnailURL: URI?,/** GIF/video width in pixels */        @SerialName("width")
        val width: Int?,/** GIF/video height in pixels */        @SerialName("height")
        val height: Int?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsMessageDefsGifEmbed"
        }
    }

    /**
     * Encrypted admin roster distributed via MLS application messages. Clients verify admin actions against this roster.
     */
    @Serializable
    data class BlueCatbirdMlsMessageDefsAdminRoster(
/** Monotonic roster version number (increments on each change) */        @SerialName("version")
        val version: Int,/** List of admin DIDs for this conversation */        @SerialName("admins")
        val admins: List<DID>,/** SHA-256 hash of (version || admins) for integrity verification */        @SerialName("hash")
        val hash: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsMessageDefsAdminRoster"
        }
    }

    /**
     * Admin action notification (E2EE). Sent alongside server API calls to inform all clients.
     */
    @Serializable
    data class BlueCatbirdMlsMessageDefsAdminAction(
/** Type of admin action performed */        @SerialName("action")
        val action: String,/** DID of member being acted upon */        @SerialName("targetDid")
        val targetDid: DID,/** When the action was performed */        @SerialName("timestamp")
        val timestamp: ATProtocolDate,/** Optional reason for the action */        @SerialName("reason")
        val reason: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsMessageDefsAdminAction"
        }
    }

    /**
     * Encrypted reaction to a message (add or remove emoji)
     */
    @Serializable
    data class BlueCatbirdMlsMessageDefsReactionPayload(
/** ID of the message being reacted to */        @SerialName("messageId")
        val messageId: String,/** Emoji reaction (single emoji or short sequence) */        @SerialName("emoji")
        val emoji: String,/** Whether to add or remove the reaction */        @SerialName("action")
        val action: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsMessageDefsReactionPayload"
        }
    }

    /**
     * Encrypted read receipt for a specific message
     */
    @Serializable
    data class BlueCatbirdMlsMessageDefsReadReceiptPayload(
/** ID of the message that was read */        @SerialName("messageId")
        val messageId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsMessageDefsReadReceiptPayload"
        }
    }

    /**
     * Encrypted typing indicator (ephemeral, not stored). Sent as MLS PrivateMessage without epoch advancement.
     */
    @Serializable
    data class BlueCatbirdMlsMessageDefsTypingPayload(
/** Whether the user is currently typing */        @SerialName("isTyping")
        val isTyping: Boolean,/** Unix timestamp in milliseconds when typing state changed */        @SerialName("ts")
        val ts: Int?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsMessageDefsTypingPayload"
        }
    }
