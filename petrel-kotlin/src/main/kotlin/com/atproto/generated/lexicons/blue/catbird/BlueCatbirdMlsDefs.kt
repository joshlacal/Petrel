// Lexicon: 1, ID: blue.catbird.mls.defs
// Shared type definitions for MLS (Message Layer Security) protocol
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsDefsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.defs"
}

    /**
     * View of an MLS conversation with member and epoch information
     */
    @Serializable
    data class BlueCatbirdMlsDefsConvoView(
/** MLS group identifier (hex-encoded) - canonical conversation ID */        @SerialName("groupId")
        val groupId: String,/** DID of the conversation creator */        @SerialName("creator")
        val creator: DID,/** Current conversation members */        @SerialName("members")
        val members: List<BlueCatbirdMlsDefsMemberView>,/** Current MLS epoch number */        @SerialName("epoch")
        val epoch: Int,/** MLS cipher suite used for this conversation */        @SerialName("cipherSuite")
        val cipherSuite: String,/** Conversation creation timestamp */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** Timestamp of last message */        @SerialName("lastMessageAt")
        val lastMessageAt: ATProtocolDate?,/** Optional conversation metadata */        @SerialName("metadata")
        val metadata: BlueCatbirdMlsDefsConvoMetadata?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsDefsConvoView"
        }
    }

    /**
     * Metadata for a conversation (name, description)
     */
    @Serializable
    data class BlueCatbirdMlsDefsConvoMetadata(
/** Conversation display name */        @SerialName("name")
        val name: String?,/** Conversation description */        @SerialName("description")
        val description: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsDefsConvoMetadata"
        }
    }

    /**
     * View of a conversation member representing a single device. Multiple devices per user appear as separate members in MLS layer, but UI should group by userDid.
     */
    @Serializable
    data class BlueCatbirdMlsDefsMemberView(
/** Device-specific MLS DID (format: did:plc:user#device-uuid). Used in MLS operations. */        @SerialName("did")
        val did: DID,/** User DID without device suffix (format: did:plc:user). Used for UI grouping and admin status sync. */        @SerialName("userDid")
        val userDid: DID,/** Device identifier (UUID). Unique per device. */        @SerialName("deviceId")
        val deviceId: String?,/** Human-readable device name (e.g., 'Josh's iPhone'). Optional, may be null for legacy members. */        @SerialName("deviceName")
        val deviceName: String?,/** When this device joined the conversation */        @SerialName("joinedAt")
        val joinedAt: ATProtocolDate,/** Whether this member (device) has admin privileges. Admin status is synced across all devices of the same user. */        @SerialName("isAdmin")
        val isAdmin: Boolean,/** When member was promoted to admin (if applicable) */        @SerialName("promotedAt")
        val promotedAt: ATProtocolDate?,/** DID of admin who promoted this member (if applicable) */        @SerialName("promotedBy")
        val promotedBy: DID?,/** MLS leaf index in ratchet tree structure */        @SerialName("leafIndex")
        val leafIndex: Int?,/** MLS credential bytes */        @SerialName("credential")
        val credential: ByteArray?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsDefsMemberView"
        }
    }

    /**
     * View of an encrypted MLS message. Server follows 'dumb delivery service' model - sender identity must be derived by clients from decrypted MLS content for metadata privacy. Server GUARANTEES: (1) Sequential (epoch, seq) assignment per conversation, (2) Monotonic seq increment, (3) No seq reuse. Clients MUST process messages in (epoch ASC, seq ASC) order for correct MLS decryption.
     */
    @Serializable
    data class BlueCatbirdMlsDefsMessageView(
/** Message identifier (ULID for deduplication) */        @SerialName("id")
        val id: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** MLS encrypted message ciphertext bytes */        @SerialName("ciphertext")
        val ciphertext: ByteArray,/** MLS epoch when message was sent */        @SerialName("epoch")
        val epoch: Int,/** Monotonically increasing sequence number within conversation. Server assigns sequentially starting from 1. Gaps may occur when members are removed from the conversation, but seq values are never reused. */        @SerialName("seq")
        val seq: Int,/** Message creation timestamp (bucketed to 2-second intervals for traffic analysis protection) */        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsDefsMessageView"
        }
    }

    /**
     * Reference to an MLS key package for adding members
     */
    @Serializable
    data class BlueCatbirdMlsDefsKeyPackageRef(
/** Owner DID */        @SerialName("did")
        val did: DID,/** Base64url-encoded MLS key package bytes */        @SerialName("keyPackage")
        val keyPackage: String,/** Hex-encoded SHA-256 hash of the key package bytes. Clients should use this server-computed hash when creating conversations to ensure hash consistency. */        @SerialName("keyPackageHash")
        val keyPackageHash: String?,/** Supported cipher suite for this key package */        @SerialName("cipherSuite")
        val cipherSuite: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsDefsKeyPackageRef"
        }
    }
