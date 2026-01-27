// Lexicon: 1, ID: com.atproto.admin.sendEmail
// Send email to a user's account email address.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoAdminSendEmailDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.sendEmail"
}

@Serializable
    data class ComAtprotoAdminSendEmailInput(
        @SerialName("recipientDid")
        val recipientDid: DID,        @SerialName("content")
        val content: String,        @SerialName("subject")
        val subject: String? = null,        @SerialName("senderDid")
        val senderDid: DID,// Additional comment by the sender that won't be used in the email itself but helpful to provide more context for moderators/reviewers        @SerialName("comment")
        val comment: String? = null    )

    @Serializable
    data class ComAtprotoAdminSendEmailOutput(
        @SerialName("sent")
        val sent: Boolean    )

/**
 * Send email to a user's account email address.
 *
 * Endpoint: com.atproto.admin.sendEmail
 */
suspend fun ATProtoClient.Com.Atproto.Admin.sendEmail(
input: ComAtprotoAdminSendEmailInput): ATProtoResponse<ComAtprotoAdminSendEmailOutput> {
    val endpoint = "com.atproto.admin.sendEmail"

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
