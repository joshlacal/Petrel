// Lexicon: 1, ID: app.bsky.contact.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyContactDefsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.contact.defs"
}

    /**
     * Associates a profile with the positional index of the contact import input in the call to `app.bsky.contact.importContacts`, so clients can know which phone caused a particular match.
     */
    @Serializable
    data class AppBskyContactDefsMatchAndContactIndex(
/** Profile of the matched user. */        @SerialName("match")
        val match: AppBskyActorDefsProfileView,/** The index of this match in the import contact input. */        @SerialName("contactIndex")
        val contactIndex: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyContactDefsMatchAndContactIndex"
        }
    }

    @Serializable
    data class AppBskyContactDefsSyncStatus(
/** Last date when contacts where imported. */        @SerialName("syncedAt")
        val syncedAt: ATProtocolDate,/** Number of existing contact matches resulting of the user imports and of their imported contacts having imported the user. Matches stop being counted when the user either follows the matched contact or dismisses the match. */        @SerialName("matchesCount")
        val matchesCount: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyContactDefsSyncStatus"
        }
    }

    /**
     * A stash object to be sent via bsync representing a notification to be created.
     */
    @Serializable
    data class AppBskyContactDefsNotification(
/** The DID of who this notification comes from. */        @SerialName("from")
        val from: DID,/** The DID of who this notification should go to. */        @SerialName("to")
        val to: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyContactDefsNotification"
        }
    }
