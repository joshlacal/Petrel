// Lexicon: 1, ID: place.stream.server.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamServerDefsDefs {
    const val TYPE_IDENTIFIER = "place.stream.server.defs"
}

    /**
     * A webhook configuration for receiving Streamplace events.
     */
    @Serializable
    data class PlaceStreamServerDefsWebhook(
/** Unique identifier for this webhook. */        @SerialName("id")
        val id: String,/** The webhook URL where events will be sent. */        @SerialName("url")
        val url: URI,/** The types of events this webhook should receive. */        @SerialName("events")
        val events: List<String>,/** Whether this webhook is currently active. */        @SerialName("active")
        val active: Boolean,/** Text to prepend to webhook messages. */        @SerialName("prefix")
        val prefix: String? = null,/** Text to append to webhook messages. */        @SerialName("suffix")
        val suffix: String? = null,/** Text replacement rules for webhook messages. */        @SerialName("rewrite")
        val rewrite: List<PlaceStreamServerDefsRewriteRule>? = null,/** When this webhook was created. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** When this webhook was last updated. */        @SerialName("updatedAt")
        val updatedAt: ATProtocolDate? = null,/** A user-friendly name for this webhook. */        @SerialName("name")
        val name: String? = null,/** A description of what this webhook is used for. */        @SerialName("description")
        val description: String? = null,/** When this webhook was last triggered. */        @SerialName("lastTriggered")
        val lastTriggered: ATProtocolDate? = null,/** Number of consecutive errors for this webhook. */        @SerialName("errorCount")
        val errorCount: Int? = null,/** Words to filter out from chat messages. Messages containing any of these words will not be forwarded. */        @SerialName("muteWords")
        val muteWords: List<String>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamServerDefsWebhook"
        }
    }

    @Serializable
    data class PlaceStreamServerDefsRewriteRule(
/** Text to search for and replace. */        @SerialName("from")
        val from: String,/** Text to replace with. */        @SerialName("to")
        val to: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamServerDefsRewriteRule"
        }
    }
