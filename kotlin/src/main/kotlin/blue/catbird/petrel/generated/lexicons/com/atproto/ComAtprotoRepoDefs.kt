// Lexicon: 1, ID: com.atproto.repo.defs

package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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
