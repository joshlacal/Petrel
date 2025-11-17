// Lexicon: 1, ID: app.bsky.video.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyVideoDefs {
    const val TYPE_IDENTIFIER = "app.bsky.video.defs"

        @Serializable
    data class Jobstatus(
        @SerialName("jobId")
        val jobId: String,        @SerialName("did")
        val did: DID,/** The state of the video processing job. All values not listed as a known value indicate that the job is in process. */        @SerialName("state")
        val state: String,/** Progress within the current processing state. */        @SerialName("progress")
        val progress: Int?,        @SerialName("blob")
        val blob: Blob?,        @SerialName("error")
        val error: String?,        @SerialName("message")
        val message: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#jobstatus"
        }
    }

}
