// Lexicon: 1, ID: app.bsky.video.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyVideoDefsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.video.defs"
}

    @Serializable
    data class AppBskyVideoDefsJobStatus(
        @SerialName("jobId")
        val jobId: String,        @SerialName("did")
        val did: DID,/** The state of the video processing job. All values not listed as a known value indicate that the job is in process. */        @SerialName("state")
        val state: String,/** Progress within the current processing state. */        @SerialName("progress")
        val progress: Int?,        @SerialName("blob")
        val blob: Blob?,        @SerialName("error")
        val error: String?,        @SerialName("message")
        val message: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyVideoDefsJobStatus"
        }
    }
