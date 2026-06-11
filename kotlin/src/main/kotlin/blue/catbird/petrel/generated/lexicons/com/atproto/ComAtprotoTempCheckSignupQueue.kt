// Lexicon: 1, ID: com.atproto.temp.checkSignupQueue
// Check accounts location in signup queue.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoTempCheckSignupQueueDefs {
    const val TYPE_IDENTIFIER = "com.atproto.temp.checkSignupQueue"
}

    @Serializable
    data class ComAtprotoTempCheckSignupQueueOutput(
        @SerialName("activated")
        val activated: Boolean,        @SerialName("placeInQueue")
        val placeInQueue: Int? = null,        @SerialName("estimatedTimeMs")
        val estimatedTimeMs: Int? = null    )

/**
 * Check accounts location in signup queue.
 *
 * Endpoint: com.atproto.temp.checkSignupQueue
 */
suspend fun ATProtoClient.Com.Atproto.Temp.checkSignupQueue(
): ATProtoResponse<ComAtprotoTempCheckSignupQueueOutput> {
    val endpoint = "com.atproto.temp.checkSignupQueue"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
