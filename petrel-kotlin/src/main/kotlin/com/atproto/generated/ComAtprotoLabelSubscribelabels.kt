// Lexicon: 1, ID: com.atproto.label.subscribeLabels
// Subscribe to stream of labels (and negations). Public endpoint implemented by mod services. Uses same sequencing scheme as repo event stream.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoLabelSubscribelabels {
    const val TYPE_IDENTIFIER = "com.atproto.label.subscribeLabels"

    @Serializable
    data class Parameters(
// The last known event seq number to backfill from.        @SerialName("cursor")
        val cursor: Int? = null    )

    sealed class Error(val name: String, val description: String?) {
        object Futurecursor: Error("FutureCursor", "")
    }

        @Serializable
    data class Labels(
        @SerialName("seq")
        val seq: Int,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefs.Label>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#labels"
        }
    }

    @Serializable
    data class Info(
        @SerialName("name")
        val name: String,        @SerialName("message")
        val message: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#info"
        }
    }

}

/**
 * Subscribe to stream of labels (and negations). Public endpoint implemented by mod services. Uses same sequencing scheme as repo event stream.
 *
 * Endpoint: com.atproto.label.subscribeLabels
 */
fun ATProtoClient.Com.Atproto.Label.subscribelabels(
parameters: ComAtprotoLabelSubscribelabels.Parameters): Flow<ComAtprotoLabelSubscribelabels.Message> = flow {
    val endpoint = "com.atproto.label.subscribeLabels"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
    }

    // WebSocket connection - implementation depends on WebSocket library
    // This would emit message_type items as they arrive
}
