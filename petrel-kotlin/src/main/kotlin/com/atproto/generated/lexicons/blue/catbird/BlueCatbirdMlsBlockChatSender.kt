// Lexicon: 1, ID: blue.catbird.mls.blockChatSender
// Block a sender and decline all their pending requests
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsBlockChatSenderDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.blockChatSender"
}

@Serializable
    data class BlueCatbirdMlsBlockChatSenderInput(
// DID of sender to block        @SerialName("senderDid")
        val senderDid: String,// Optional specific request ID that prompted block        @SerialName("requestId")
        val requestId: String? = null,// Reason for blocking        @SerialName("reason")
        val reason: String? = null    )

    @Serializable
    data class BlueCatbirdMlsBlockChatSenderOutput(
        @SerialName("success")
        val success: Boolean,// Number of requests declined        @SerialName("blockedCount")
        val blockedCount: Int    )

/**
 * Block a sender and decline all their pending requests
 *
 * Endpoint: blue.catbird.mls.blockChatSender
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.blockChatSender(
input: BlueCatbirdMlsBlockChatSenderInput): ATProtoResponse<BlueCatbirdMlsBlockChatSenderOutput> {
    val endpoint = "blue.catbird.mls.blockChatSender"

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
