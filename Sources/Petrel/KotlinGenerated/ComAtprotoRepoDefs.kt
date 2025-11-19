// Lexicon: 1, ID: com.atproto.repo.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoRepoDefs {
    const val TYPE_IDENTIFIER = "com.atproto.repo.defs"

        @Serializable
    data class Commitmeta(
        @SerialName("cid")
        val cid: CID,        @SerialName("rev")
        val rev: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#commitmeta"
        }
    }

}
