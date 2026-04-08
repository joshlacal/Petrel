// Lexicon: 1, ID: com.atproto.repo.strongRef
// A URI with a content-hash fingerprint.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoRepoStrongRefDefs {
    const val TYPE_IDENTIFIER = "com.atproto.repo.strongRef"
}

@Serializable
data class ComAtprotoRepoStrongRef(
    @SerialName("uri")
    val uri: ATProtocolURI,    @SerialName("cid")
    val cid: CID)
