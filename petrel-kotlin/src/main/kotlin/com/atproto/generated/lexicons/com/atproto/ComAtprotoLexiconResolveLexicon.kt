// Lexicon: 1, ID: com.atproto.lexicon.resolveLexicon
// Resolves an atproto lexicon (NSID) to a schema.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoLexiconResolveLexiconDefs {
    const val TYPE_IDENTIFIER = "com.atproto.lexicon.resolveLexicon"
}

@Serializable
    data class ComAtprotoLexiconResolveLexiconParameters(
// The lexicon NSID to resolve.        @SerialName("nsid")
        val nsid: NSID    )

    @Serializable
    data class ComAtprotoLexiconResolveLexiconOutput(
// The CID of the lexicon schema record.        @SerialName("cid")
        val cid: CID,// The resolved lexicon schema record.        @SerialName("schema")
        val schema: ComAtprotoLexiconSchema,// The AT-URI of the lexicon schema record.        @SerialName("uri")
        val uri: ATProtocolURI    )

sealed class ComAtprotoLexiconResolveLexiconError(val name: String, val description: String?) {
        object LexiconNotFound: ComAtprotoLexiconResolveLexiconError("LexiconNotFound", "No lexicon was resolved for the NSID.")
    }

/**
 * Resolves an atproto lexicon (NSID) to a schema.
 *
 * Endpoint: com.atproto.lexicon.resolveLexicon
 */
suspend fun ATProtoClient.Com.Atproto.Lexicon.resolveLexicon(
parameters: ComAtprotoLexiconResolveLexiconParameters): ATProtoResponse<ComAtprotoLexiconResolveLexiconOutput> {
    val endpoint = "com.atproto.lexicon.resolveLexicon"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
