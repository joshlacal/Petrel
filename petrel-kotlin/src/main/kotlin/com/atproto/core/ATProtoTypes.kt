package com.atproto.core

import kotlinx.serialization.*
import kotlinx.serialization.descriptors.*
import kotlinx.serialization.encoding.*
import kotlinx.datetime.Instant

// MARK: - AT Protocol Date

@Serializable(with = ATProtocolDateSerializer::class)
data class ATProtocolDate(val instant: Instant) {
    override fun toString(): String = instant.toString()

    companion object {
        fun now() = ATProtocolDate(Instant.now())
        fun fromString(s: String) = ATProtocolDate(Instant.parse(s))
    }
}

object ATProtocolDateSerializer : KSerializer<ATProtocolDate> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("ATProtocolDate", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: ATProtocolDate) {
        encoder.encodeString(value.instant.toString())
    }

    override fun deserialize(decoder: Decoder): ATProtocolDate {
        val string = decoder.decodeString()
        return ATProtocolDate(Instant.parse(string))
    }
}

// MARK: - URIs

@Serializable(with = ATProtocolURISerializer::class)
data class ATProtocolURI(
    val authority: String,
    val collection: String? = null,
    val recordKey: String? = null
) {
    init {
        require(authority.isNotEmpty()) { "Authority cannot be empty" }
        require(toString().length <= 8192) { "URI too long" }
    }

    override fun toString(): String {
        val builder = StringBuilder("at://").append(authority)
        collection?.let { builder.append("/").append(it) }
        recordKey?.let { builder.append("/").append(it) }
        return builder.toString()
    }

    companion object {
        fun parse(uriString: String): ATProtocolURI {
            require(uriString.startsWith("at://")) { "Invalid AT URI format" }
            require(uriString.length > 5) { "Invalid AT URI: too short" }

            val parts = uriString.substring(5).split("/")
            require(parts.isNotEmpty() && parts[0].isNotEmpty()) { "Invalid AT URI: missing authority" }

            return ATProtocolURI(
                authority = parts[0],
                collection = parts.getOrNull(1)?.takeIf { it.isNotEmpty() },
                recordKey = parts.getOrNull(2)?.takeIf { it.isNotEmpty() }
            )
        }
    }
}

object ATProtocolURISerializer : KSerializer<ATProtocolURI> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("ATProtocolURI", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: ATProtocolURI) {
        encoder.encodeString(value.toString())
    }

    override fun deserialize(decoder: Decoder): ATProtocolURI {
        return ATProtocolURI.parse(decoder.decodeString())
    }
}

@Serializable(with = URISerializer::class)
data class URI(
    val scheme: String,
    val authority: String,
    val path: String? = null,
    val query: String? = null,
    val fragment: String? = null
) {
    val isDID: Boolean = scheme == "did"

    override fun toString(): String {
        return if (isDID) {
            buildString {
                append("did:").append(authority)
                path?.let { append(":").append(it) }
            }
        } else {
            buildString {
                append(scheme).append("://").append(authority)
                path?.let { append(it) }
                query?.let { append("?").append(it) }
                fragment?.let { append("#").append(it) }
            }
        }
    }

    companion object {
        fun parse(uriString: String): URI {
            val trimmed = uriString.trim()

            return if (trimmed.startsWith("did:")) {
                val parts = trimmed.split(":")
                require(parts.size >= 3) { "Invalid DID format" }
                URI(
                    scheme = "did",
                    authority = parts[1],
                    path = parts.drop(2).joinToString(":").takeIf { it.isNotEmpty() }
                )
            } else {
                val schemeEnd = trimmed.indexOf("://")
                if (schemeEnd == -1) {
                    URI(scheme = "https", authority = "invalid.invalid")
                } else {
                    val scheme = trimmed.substring(0, schemeEnd)
                    val rest = trimmed.substring(schemeEnd + 3)
                    val authorityEnd = rest.indexOfAny(charArrayOf('/', '?', '#')).takeIf { it != -1 } ?: rest.length
                    val authority = rest.substring(0, authorityEnd)

                    var path: String? = null
                    var query: String? = null
                    var fragment: String? = null

                    if (authorityEnd < rest.length) {
                        val remaining = rest.substring(authorityEnd)
                        val queryStart = remaining.indexOf('?')
                        val fragmentStart = remaining.indexOf('#')

                        when {
                            queryStart != -1 && fragmentStart != -1 -> {
                                path = remaining.substring(0, queryStart)
                                query = remaining.substring(queryStart + 1, fragmentStart)
                                fragment = remaining.substring(fragmentStart + 1)
                            }
                            queryStart != -1 -> {
                                path = remaining.substring(0, queryStart)
                                query = remaining.substring(queryStart + 1)
                            }
                            fragmentStart != -1 -> {
                                path = remaining.substring(0, fragmentStart)
                                fragment = remaining.substring(fragmentStart + 1)
                            }
                            else -> {
                                path = remaining
                            }
                        }
                    }

                    URI(scheme, authority, path, query, fragment)
                }
            }
        }
    }
}

object URISerializer : KSerializer<URI> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("URI", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: URI) {
        encoder.encodeString(value.toString())
    }

    override fun deserialize(decoder: Decoder): URI {
        return URI.parse(decoder.decodeString())
    }
}

// MARK: - DID

@Serializable(with = DIDSerializer::class)
data class DID(
    val method: String,
    val authority: String,
    val segments: List<String> = emptyList()
) {
    init {
        require(method.isNotEmpty()) { "DID method cannot be empty" }
        require(authority.isNotEmpty()) { "DID authority cannot be empty" }
        require(toString().length <= 8192) { "DID too long" }
    }

    override fun toString(): String {
        val builder = StringBuilder("did:").append(method).append(":").append(authority)
        segments.forEach { builder.append(":").append(it) }
        return builder.toString()
    }

    companion object {
        fun parse(didString: String): DID {
            require(didString.startsWith("did:")) { "Invalid DID format" }
            require(didString.length > 4) { "Invalid DID: too short" }

            val parts = didString.substring(4).split(":")
            require(parts.size >= 2) { "Invalid DID: missing method or authority" }

            return DID(
                method = parts[0],
                authority = parts[1],
                segments = parts.drop(2)
            )
        }
    }
}

object DIDSerializer : KSerializer<DID> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("DID", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: DID) {
        encoder.encodeString(value.toString())
    }

    override fun deserialize(decoder: Decoder): DID {
        return DID.parse(decoder.decodeString())
    }
}

// MARK: - Handle

@Serializable(with = HandleSerializer::class)
data class Handle(val value: String) {
    init {
        require(isValid(value)) { "Invalid handle format: $value" }
    }

    override fun toString(): String = value

    companion object {
        private val handleRegex = Regex(
            "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))+$"
        )

        fun isValid(handle: String): Boolean {
            return handle.isNotEmpty() && handle.length <= 253 && handleRegex.matches(handle)
        }
    }
}

object HandleSerializer : KSerializer<Handle> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("Handle", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: Handle) {
        encoder.encodeString(value.value)
    }

    override fun deserialize(decoder: Decoder): Handle {
        return Handle(decoder.decodeString())
    }
}

// MARK: - AT Identifier

@Serializable(with = ATIdentifierSerializer::class)
sealed class ATIdentifier {
    data class DIDIdentifier(val did: DID) : ATIdentifier()
    data class HandleIdentifier(val handle: Handle) : ATIdentifier()

    override fun toString(): String = when (this) {
        is DIDIdentifier -> did.toString()
        is HandleIdentifier -> handle.toString()
    }

    companion object {
        fun parse(value: String): ATIdentifier {
            return if (value.startsWith("did:")) {
                DIDIdentifier(DID.parse(value))
            } else {
                HandleIdentifier(Handle(value))
            }
        }
    }
}

object ATIdentifierSerializer : KSerializer<ATIdentifier> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("ATIdentifier", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: ATIdentifier) {
        encoder.encodeString(value.toString())
    }

    override fun deserialize(decoder: Decoder): ATIdentifier {
        return ATIdentifier.parse(decoder.decodeString())
    }
}

// MARK: - CID

@Serializable(with = CIDSerializer::class)
data class CID(val value: String) {
    init {
        require(value.isNotEmpty()) { "CID cannot be empty" }
    }

    override fun toString(): String = value
}

object CIDSerializer : KSerializer<CID> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("CID", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: CID) {
        encoder.encodeString(value.value)
    }

    override fun deserialize(decoder: Decoder): CID {
        return CID(decoder.decodeString())
    }
}

// MARK: - NSID

@Serializable(with = NSIDSerializer::class)
data class NSID(val authority: String, val name: String) {
    override fun toString(): String = "$authority.$name"

    companion object {
        fun parse(nsidString: String): NSID {
            val parts = nsidString.split(".")
            require(parts.size >= 2) { "Invalid NSID format" }
            return NSID(
                authority = parts.dropLast(1).joinToString("."),
                name = parts.last()
            )
        }
    }
}

object NSIDSerializer : KSerializer<NSID> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("NSID", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: NSID) {
        encoder.encodeString(value.toString())
    }

    override fun deserialize(decoder: Decoder): NSID {
        return NSID.parse(decoder.decodeString())
    }
}

// MARK: - Language

@Serializable(with = LanguageSerializer::class)
data class Language(val value: String) {
    override fun toString(): String = value
}

object LanguageSerializer : KSerializer<Language> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("Language", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: Language) {
        encoder.encodeString(value.value)
    }

    override fun deserialize(decoder: Decoder): Language {
        return Language(decoder.decodeString())
    }
}

// MARK: - Blob

@Serializable
data class Blob(
    @SerialName("\$type")
    val type: String = "blob",
    val ref: ATProtoLink? = null,
    val mimeType: String,
    val size: Int,
    val cid: String? = null
)

@Serializable
data class ATProtoLink(
    @SerialName("\$link")
    val link: String
)

// MARK: - Bytes

@Serializable(with = BytesSerializer::class)
data class Bytes(val data: ByteArray) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is Bytes) return false
        return data.contentEquals(other.data)
    }

    override fun hashCode(): Int = data.contentHashCode()
}

object BytesSerializer : KSerializer<Bytes> {
    override val descriptor: SerialDescriptor =
        buildClassSerialDescriptor("Bytes") {
            element<String>("\$bytes")
        }

    override fun serialize(encoder: Encoder, value: Bytes) {
        encoder.encodeStructure(descriptor) {
            encodeStringElement(descriptor, 0, Base64.getEncoder().encodeToString(value.data))
        }
    }

    override fun deserialize(decoder: Decoder): Bytes {
        return decoder.decodeStructure(descriptor) {
            var base64String = ""
            while (true) {
                when (val index = decodeElementIndex(descriptor)) {
                    0 -> base64String = decodeStringElement(descriptor, 0)
                    CompositeDecoder.DECODE_DONE -> break
                    else -> error("Unexpected index: $index")
                }
            }
            Bytes(Base64.getDecoder().decode(base64String))
        }
    }
}
