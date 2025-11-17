// Lexicon: 1, ID: com.atproto.repo.strongRef
// A URI with a content-hash fingerprint.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoRepoStrongref {
    const val TYPE_IDENTIFIER = "com.atproto.repo.strongRef"

    @Serializable
data class ComAtprotoRepoStrongref(
    @SerialName("uri")
    val uri: ATProtocolURI,    @SerialName("cid")
    val cid: CID)
}
