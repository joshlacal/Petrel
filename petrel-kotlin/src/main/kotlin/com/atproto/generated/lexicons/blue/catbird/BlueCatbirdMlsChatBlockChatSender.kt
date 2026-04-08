// Lexicon: 1, ID: blue.catbird.mlsChat.blockChatSender
// Block a sender and decline all their pending requests
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatBlockChatSenderDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.blockChatSender"
}

@Serializable
    data class BlueCatbirdMlsChatBlockChatSenderInput(
// DID of sender to block        @SerialName("senderDid")
        val senderDid: String,// Optional specific request ID that prompted block        @SerialName("requestId")
        val requestId: String? = null,// Reason for blocking        @SerialName("reason")
        val reason: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatBlockChatSenderOutput(
        @SerialName("success")
        val success: Boolean,// Number of requests declined        @SerialName("blockedCount")
        val blockedCount: Int    )

/**
 * Block a sender and decline all their pending requests
 *
 * Endpoint: blue.catbird.mlsChat.blockChatSender
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.blockChatSender(
input: BlueCatbirdMlsChatBlockChatSenderInput): ATProtoResponse<BlueCatbirdMlsChatBlockChatSenderOutput> {
    val endpoint = "blue.catbird.mlsChat.blockChatSender"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
