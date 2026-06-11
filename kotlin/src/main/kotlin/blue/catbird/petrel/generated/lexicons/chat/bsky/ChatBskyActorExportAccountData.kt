// Lexicon: 1, ID: chat.bsky.actor.exportAccountData

package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyActorExportAccountDataDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.actor.exportAccountData"
}

    @Serializable
    data class ChatBskyActorExportAccountDataOutput(
        @SerialName("data")
        val `data`: ByteArray    )

/**
 * 
 *
 * Endpoint: chat.bsky.actor.exportAccountData
 */
suspend fun ATProtoClient.Chat.Bsky.Actor.exportAccountData(
): ATProtoResponse<ChatBskyActorExportAccountDataOutput> {
    val endpoint = "chat.bsky.actor.exportAccountData"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/jsonl"),
        body = null
    )
}
