// Lexicon: 1, ID: com.atproto.lexicon.schema
// Representation of Lexicon schemas themselves, when published as atproto records. Note that the schema language is not defined in Lexicon; this meta schema currently only includes a single version field ('lexicon'). See the atproto specifications for description of the other expected top-level fields ('id', 'defs', etc).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoLexiconSchema {
    const val TYPE_IDENTIFIER = "com.atproto.lexicon.schema"

        /**
     * Representation of Lexicon schemas themselves, when published as atproto records. Note that the schema language is not defined in Lexicon; this meta schema currently only includes a single version field ('lexicon'). See the atproto specifications for description of the other expected top-level fields ('id', 'defs', etc).
     */
    @Serializable
    data class Record(
/** Indicates the 'version' of the Lexicon language. Must be '1' for the current atproto/Lexicon schema system. */        @SerialName("lexicon")
        val lexicon: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }

}
