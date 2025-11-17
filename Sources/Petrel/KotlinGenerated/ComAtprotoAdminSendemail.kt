// Lexicon: 1, ID: com.atproto.admin.sendEmail
// Send email to a user's account email address.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoAdminSendemail {
    const val TYPE_IDENTIFIER = "com.atproto.admin.sendEmail"

    @Serializable
    data class Input(
        @SerialName("recipientDid")
        val recipientDid: DID,        @SerialName("content")
        val content: String,        @SerialName("subject")
        val subject: String? = null,        @SerialName("senderDid")
        val senderDid: DID,// Additional comment by the sender that won't be used in the email itself but helpful to provide more context for moderators/reviewers        @SerialName("comment")
        val comment: String? = null    )

        @Serializable
    data class Output(
        @SerialName("sent")
        val sent: Boolean    )

}

/**
 * Send email to a user's account email address.
 *
 * Endpoint: com.atproto.admin.sendEmail
 */
suspend fun ATProtoClient.Com.Atproto.Admin.sendemail(
input: ComAtprotoAdminSendemail.Input): ATProtoResponse<ComAtprotoAdminSendemail.Output> {
    val endpoint = "com.atproto.admin.sendEmail"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
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
