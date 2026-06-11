// Lexicon: 1, ID: app.bsky.video.defs

package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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
        val progress: Int? = null,        @SerialName("blob")
        val blob: Blob? = null,        @SerialName("error")
        val error: String? = null,        @SerialName("message")
        val message: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyVideoDefsJobStatus"
        }
    }
