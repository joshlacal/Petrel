package com.atproto.core.types

import kotlinx.serialization.*
import kotlinx.serialization.descriptors.*
import kotlinx.serialization.encoding.*
import kotlinx.serialization.json.*
import kotlin.io.encoding.Base64
import kotlin.io.encoding.ExperimentalEncodingApi

// MARK: - URI

@Serializable(with = URISerializer::class)
data class URI(
    val scheme: String,
    val authority: String,
    val path: String? = null,
    val query: String? = null,
    val fragment: String? = null
) {
    override fun toString(): String {
        val builder = StringBuilder()
        builder.append(scheme).append("://").append(authority)
        path?.let { builder.append(it) }
        query?.let { builder.append("?").append(it) }
        fragment?.let { builder.append("#").append(it) }
        return builder.toString()
    }

    companion object {
        fun parse(uriString: String): URI {
            val trimmed = uriString.trim()
            if (trimmed.startsWith("did:")) {
                val parts = trimmed.split(":")
                require(parts.size >= 3) { "Invalid DID format" }
                return URI(
                    scheme = "did",
                    authority = parts[1],
                    path = parts.drop(2).joinToString(":").takeIf { it.isNotEmpty() }
                )
            } else {
                val schemeEnd = trimmed.indexOf("://")
                if (schemeEnd == -1) {
                    return URI(scheme = "https", authority = "invalid.invalid")
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

                    return URI(scheme, authority, path, query, fragment)
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

@OptIn(ExperimentalEncodingApi::class)
object BytesSerializer : KSerializer<Bytes> {
    override val descriptor: SerialDescriptor =
        buildClassSerialDescriptor("Bytes") {
            element<String>("\$bytes")
        }

    override fun serialize(encoder: Encoder, value: Bytes) {
        // JSON encoder: emit {"$bytes": "base64..."} matching the AT Protocol
        // convention used by Swift's Bytes and Jacquard's serde_bytes_helper.
        // Non-JSON encoders (CBOR, etc.) fall through to the structured path,
        // which is what Jacquard's DAG-CBOR encoding expects.
        if (encoder is JsonEncoder) {
            val obj = buildJsonObject {
                put("\$bytes", JsonPrimitive(Base64.encode(value.data)))
            }
            encoder.encodeJsonElement(obj)
            return
        }
        encoder.encodeStructure(descriptor) {
            encodeStringElement(descriptor, 0, Base64.encode(value.data))
        }
    }

    override fun deserialize(decoder: Decoder): Bytes {
        // The canonical JSON wire format for ATProto `bytes` is
        // `{"$bytes": "<base64>"}` — confirmed against Swift Petrel's Bytes
        // and Jacquard's `serde_bytes_helper` (human-readable serialize
        // branch). Earlier versions of this deserializer used
        // `decodeStructure`; on kotlinx-serialization + ktor-json that path
        // silently returned the base64 bytes un-decoded (as ASCII) for some
        // payload shapes, so every XRPC call that returned a `bytes`-typed
        // field handed callers the ASCII of the base64 string instead of
        // the decoded payload. Use JsonDecoder's raw-element peek so we can
        // reliably unwrap the `$bytes` key (and accept a plain base64
        // string as a defensive legacy form).
        if (decoder is JsonDecoder) {
            val element = decoder.decodeJsonElement()
            val base64 = when (element) {
                is JsonPrimitive ->
                    if (element.isString) element.content
                    else throw SerializationException(
                        "Bytes expects \$bytes-wrapped object or base64 string, got $element"
                    )
                is JsonObject -> element["\$bytes"]?.jsonPrimitive?.contentOrNull
                    ?: throw SerializationException(
                        "Bytes JSON object missing \$bytes field: $element"
                    )
                else -> throw SerializationException(
                    "Unexpected JSON shape for Bytes: $element"
                )
            }
            return Bytes(Base64.decode(base64))
        }

        // Non-JSON (CBOR, etc.) — keep the structured decoding path.
        return decoder.decodeStructure(descriptor) {
            var base64String = ""
            while (true) {
                when (val index = decodeElementIndex(descriptor)) {
                    0 -> base64String = decodeStringElement(descriptor, 0)
                    CompositeDecoder.DECODE_DONE -> break
                    else -> error("Unexpected index: $index")
                }
            }
            Bytes(Base64.decode(base64String))
        }
    }
}

// MARK: - AT Protocol Date

@Serializable(with = ATProtocolDateSerializer::class)
data class ATProtocolDate(val value: String) {
    override fun toString(): String = value
}

object ATProtocolDateSerializer : KSerializer<ATProtocolDate> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("ATProtocolDate", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: ATProtocolDate) {
        encoder.encodeString(value.value)
    }

    override fun deserialize(decoder: Decoder): ATProtocolDate {
        return ATProtocolDate(decoder.decodeString())
    }
}
// MARK: - AT Protocol URI

@Serializable(with = ATProtocolURISerializer::class)
data class ATProtocolURI(val value: String) {
    override fun toString(): String = value
}

object ATProtocolURISerializer : KSerializer<ATProtocolURI> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("ATProtocolURI", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: ATProtocolURI) {
        encoder.encodeString(value.value)
    }

    override fun deserialize(decoder: Decoder): ATProtocolURI {
        return ATProtocolURI(decoder.decodeString())
    }
}
