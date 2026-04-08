// Lexicon: 1, ID: com.atproto.repo.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoRepoDefsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.repo.defs"
}

    @Serializable
    data class ComAtprotoRepoDefsCommitMeta(
        @SerialName("cid")
        val cid: CID,        @SerialName("rev")
        val rev: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoRepoDefsCommitMeta"
        }
    }
