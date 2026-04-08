// Lexicon: 1, ID: app.bsky.notification.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyNotificationDefsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.notification.defs"
}

    @Serializable
    class AppBskyNotificationDefsRecordDeleted {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyNotificationDefsRecordDeleted"
        }
    }

    @Serializable
    data class AppBskyNotificationDefsChatPreference(
        @SerialName("include")
        val include: String,        @SerialName("push")
        val push: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyNotificationDefsChatPreference"
        }
    }

    @Serializable
    data class AppBskyNotificationDefsFilterablePreference(
        @SerialName("include")
        val include: String,        @SerialName("list")
        val list: Boolean,        @SerialName("push")
        val push: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyNotificationDefsFilterablePreference"
        }
    }

    @Serializable
    data class AppBskyNotificationDefsPreference(
        @SerialName("list")
        val list: Boolean,        @SerialName("push")
        val push: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyNotificationDefsPreference"
        }
    }

    @Serializable
    data class AppBskyNotificationDefsPreferences(
        @SerialName("chat")
        val chat: AppBskyNotificationDefsChatPreference,        @SerialName("follow")
        val follow: AppBskyNotificationDefsFilterablePreference,        @SerialName("like")
        val like: AppBskyNotificationDefsFilterablePreference,        @SerialName("likeViaRepost")
        val likeViaRepost: AppBskyNotificationDefsFilterablePreference,        @SerialName("mention")
        val mention: AppBskyNotificationDefsFilterablePreference,        @SerialName("quote")
        val quote: AppBskyNotificationDefsFilterablePreference,        @SerialName("reply")
        val reply: AppBskyNotificationDefsFilterablePreference,        @SerialName("repost")
        val repost: AppBskyNotificationDefsFilterablePreference,        @SerialName("repostViaRepost")
        val repostViaRepost: AppBskyNotificationDefsFilterablePreference,        @SerialName("starterpackJoined")
        val starterpackJoined: AppBskyNotificationDefsPreference,        @SerialName("subscribedPost")
        val subscribedPost: AppBskyNotificationDefsPreference,        @SerialName("unverified")
        val unverified: AppBskyNotificationDefsPreference,        @SerialName("verified")
        val verified: AppBskyNotificationDefsPreference    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyNotificationDefsPreferences"
        }
    }

    @Serializable
    data class AppBskyNotificationDefsActivitySubscription(
        @SerialName("post")
        val post: Boolean,        @SerialName("reply")
        val reply: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyNotificationDefsActivitySubscription"
        }
    }

    /**
     * Object used to store activity subscription data in stash.
     */
    @Serializable
    data class AppBskyNotificationDefsSubjectActivitySubscription(
        @SerialName("subject")
        val subject: DID,        @SerialName("activitySubscription")
        val activitySubscription: AppBskyNotificationDefsActivitySubscription    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyNotificationDefsSubjectActivitySubscription"
        }
    }
