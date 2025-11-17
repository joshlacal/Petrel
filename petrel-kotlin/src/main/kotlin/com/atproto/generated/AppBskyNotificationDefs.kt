// Lexicon: 1, ID: app.bsky.notification.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyNotificationDefs {
    const val TYPE_IDENTIFIER = "app.bsky.notification.defs"

        @Serializable
    data class Recorddeleted(
    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#recorddeleted"
        }
    }

    @Serializable
    data class Chatpreference(
        @SerialName("include")
        val include: String,        @SerialName("push")
        val push: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatpreference"
        }
    }

    @Serializable
    data class Filterablepreference(
        @SerialName("include")
        val include: String,        @SerialName("list")
        val list: Boolean,        @SerialName("push")
        val push: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#filterablepreference"
        }
    }

    @Serializable
    data class Preference(
        @SerialName("list")
        val list: Boolean,        @SerialName("push")
        val push: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#preference"
        }
    }

    @Serializable
    data class Preferences(
        @SerialName("chat")
        val chat: Chatpreference,        @SerialName("follow")
        val follow: Filterablepreference,        @SerialName("like")
        val like: Filterablepreference,        @SerialName("likeViaRepost")
        val likeViaRepost: Filterablepreference,        @SerialName("mention")
        val mention: Filterablepreference,        @SerialName("quote")
        val quote: Filterablepreference,        @SerialName("reply")
        val reply: Filterablepreference,        @SerialName("repost")
        val repost: Filterablepreference,        @SerialName("repostViaRepost")
        val repostViaRepost: Filterablepreference,        @SerialName("starterpackJoined")
        val starterpackJoined: Preference,        @SerialName("subscribedPost")
        val subscribedPost: Preference,        @SerialName("unverified")
        val unverified: Preference,        @SerialName("verified")
        val verified: Preference    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#preferences"
        }
    }

    @Serializable
    data class Activitysubscription(
        @SerialName("post")
        val post: Boolean,        @SerialName("reply")
        val reply: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#activitysubscription"
        }
    }

    /**
     * Object used to store activity subscription data in stash.
     */
    @Serializable
    data class Subjectactivitysubscription(
        @SerialName("subject")
        val subject: DID,        @SerialName("activitySubscription")
        val activitySubscription: Activitysubscription    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#subjectactivitysubscription"
        }
    }

}
