// Lexicon: 1, ID: place.stream.video
// Record representing a video on Streamplace
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamVideoDefs {
    const val TYPE_IDENTIFIER = "place.stream.video"
}

    /**
     * Record representing a video on Streamplace
     */
    @Serializable
    data class PlaceStreamVideo(
/** The title of the video. */        @SerialName("title")
        val title: String,/** The duration of the video in nanoseconds. */        @SerialName("duration")
        val duration: Int? = null,/** Client-declared timestamp when this video was created. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("thumb")
        val thumb: Blob? = null,/** Optional description of the video. */        @SerialName("description")
        val description: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
