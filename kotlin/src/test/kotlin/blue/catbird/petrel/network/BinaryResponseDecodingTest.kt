package blue.catbird.petrel.network

import blue.catbird.petrel.client.ATProtoClient
import blue.catbird.petrel.core.types.CID
import blue.catbird.petrel.core.types.DID
import blue.catbird.petrel.core.types.SpaceRef
import blue.catbird.petrel.generated.ComAtprotoSpaceExportSpaceMetaParameters
import blue.catbird.petrel.generated.ComAtprotoSyncGetBlobParameters
import blue.catbird.petrel.generated.exportSpaceMeta
import blue.catbird.petrel.generated.getBlob
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlinx.coroutines.test.runTest

/**
 * Endpoints whose lexicon output is a raw (non-JSON) body return a one-field
 * `data: ByteArray` wrapper. The generated function must fetch the body as
 * ByteArray and wrap it; asking the runtime to JSON-decode the wrapper from a
 * binary body yields a 200 with `data = null`.
 */
class BinaryResponseDecodingTest {

    // Not valid UTF-8 and not JSON: a STAR/CAR-like binary payload.
    private val body = byteArrayOf(
        0x0A, 0xA2.toByte(), 0x65, 0x72, 0x6F, 0x6F, 0x74, 0x73, 0x00, 0xFF.toByte(),
        0x80.toByte(), 0x7B, 0x01, 0x02, 0x03
    )

    private class Captured {
        var accept: String? = null
        var path: String? = null
    }

    private fun clientServing(
        contentType: String,
        status: HttpStatusCode = HttpStatusCode.OK,
        content: ByteArray = body,
        captured: Captured = Captured(),
    ): ATProtoClient {
        val engine = MockEngine { request ->
            captured.accept = request.headers[HttpHeaders.Accept]
            captured.path = request.url.encodedPath
            respond(
                content = content,
                status = status,
                headers = headersOf(HttpHeaders.ContentType, contentType)
            )
        }
        val network = NetworkService(
            baseUrl = "https://space.example.com",
            client = HttpClient(engine)
        )
        return ATProtoClient(network)
    }

    @Test
    fun `exportSpaceMeta returns octet-stream body as bytes`() = runTest {
        val captured = Captured()
        val client = clientServing("application/octet-stream", captured = captured)

        val response = client.com.atproto.space.exportSpaceMeta(
            ComAtprotoSpaceExportSpaceMetaParameters(
                space = SpaceRef.parse("at://did:plc:owner/space/blue.catbird.circle/3abc")
            )
        )

        assertEquals(200, response.responseCode)
        val data = assertNotNull(response.data, "binary 200 must not decode to null")
        assertContentEquals(body, data.data)
        assertEquals("application/octet-stream", captured.accept)
        assertEquals("/xrpc/com.atproto.space.exportSpaceMeta", captured.path)
    }

    @Test
    fun `sync getBlob returns octet-stream body as bytes`() = runTest {
        val captured = Captured()
        val client = clientServing("application/octet-stream", captured = captured)

        val response = client.com.atproto.sync.getBlob(
            ComAtprotoSyncGetBlobParameters(
                did = DID.parse("did:plc:owner"),
                cid = CID("bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy")
            )
        )

        assertEquals(200, response.responseCode)
        val data = assertNotNull(response.data, "binary 200 must not decode to null")
        assertContentEquals(body, data.data)
        assertEquals("*/*", captured.accept)
    }

    @Test
    fun `binary endpoint error keeps status and error body with null data`() = runTest {
        val errorJson = """{"error":"SpaceNotFound","message":"no such space"}"""
        val client = clientServing(
            contentType = "application/json",
            status = HttpStatusCode.BadRequest,
            content = errorJson.encodeToByteArray()
        )

        val response = client.com.atproto.space.exportSpaceMeta(
            ComAtprotoSpaceExportSpaceMetaParameters(
                space = SpaceRef.parse("at://did:plc:owner/space/blue.catbird.circle/3abc")
            )
        )

        assertEquals(400, response.responseCode)
        assertNull(response.data)
        assertEquals(errorJson, response.errorBody)
    }
}
