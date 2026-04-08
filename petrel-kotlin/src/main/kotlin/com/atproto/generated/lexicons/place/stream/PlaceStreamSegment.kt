// Lexicon: 1, ID: place.stream.segment
// Media file representing a segment of a livestream
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamSegmentDefs {
    const val TYPE_IDENTIFIER = "place.stream.segment"
}

    @Serializable
    data class PlaceStreamSegmentAudio(
        @SerialName("codec")
        val codec: String,        @SerialName("rate")
        val rate: Int,        @SerialName("channels")
        val channels: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamSegmentAudio"
        }
    }

    @Serializable
    data class PlaceStreamSegmentVideo(
        @SerialName("codec")
        val codec: String,        @SerialName("width")
        val width: Int,        @SerialName("height")
        val height: Int,        @SerialName("framerate")
        val framerate: PlaceStreamSegmentFramerate?,        @SerialName("bframes")
        val bframes: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamSegmentVideo"
        }
    }

    @Serializable
    data class PlaceStreamSegmentFramerate(
        @SerialName("num")
        val num: Int,        @SerialName("den")
        val den: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamSegmentFramerate"
        }
    }

    @Serializable
    data class PlaceStreamSegmentSegmentView(
        @SerialName("cid")
        val cid: CID,        @SerialName("record")
        val record: JsonElement    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamSegmentSegmentView"
        }
    }

    /**
     * Media file representing a segment of a livestream
     */
    @Serializable
    data class PlaceStreamSegment(
/** Unique identifier for the segment */        @SerialName("id")
        val id: String,/** The DID of the signing key used for this segment */        @SerialName("signingKey")
        val signingKey: String,/** When this segment started */        @SerialName("startTime")
        val startTime: ATProtocolDate,/** The duration of the segment in nanoseconds */        @SerialName("duration")
        val duration: Int? = null,        @SerialName("creator")
        val creator: DID,        @SerialName("video")
        val video: List<PlaceStreamSegmentVideo>? = null,        @SerialName("audio")
        val audio: List<PlaceStreamSegmentAudio>? = null,/** The size of the segment in bytes */        @SerialName("size")
        val size: Int? = null,        @SerialName("contentWarnings")
        val contentWarnings: PlaceStreamMetadataContentWarnings? = null,        @SerialName("contentRights")
        val contentRights: PlaceStreamMetadataContentRights? = null,        @SerialName("distributionPolicy")
        val distributionPolicy: PlaceStreamMetadataDistributionPolicy? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
