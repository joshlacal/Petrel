package com.atproto.client

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Tests for the hand-written WebSocket realtime parser in
 * [MlsChatRealtimeTypes]. Specifically guards the Phase 2.5
 * `#resetRequestedEvent` dispatch added to support
 * [MlsChatResetRequestedEvent].
 *
 * The bridge classes' shape is the source of truth here, but field names
 * MUST match `BlueCatbirdMlsChatSubscribeEventsResetRequestedEvent` in
 * the generated codegen, which in turn matches the server-side wire
 * emission in `mls-ds/server/src/realtime/sse.rs`.
 */
class MlsChatRealtimeTypesTest {

    @Test
    fun resetRequestedEventFullPayloadParses() {
        val frame = """
            {
              "t": "event",
              "seq": 42,
              "payload": {
                "${'$'}type": "blue.catbird.mlsChat.subscribeEvents#resetRequestedEvent",
                "cursor": "100",
                "convoId": "convo-abc",
                "cryptoSessionId": "csess-123",
                "generation": 7,
                "trigger": "quorum",
                "requestEventId": "evt-9001",
                "expectedNewMlsGroupId": "grp-future-xyz",
                "reason": "epoch spiral",
                "requestedAt": "2026-04-28T10:11:12Z"
              }
            }
        """.trimIndent()

        val msg = parseRealtimeMessage(frame)
        assertIs<MlsChatRealtimeMessage.Event>(msg)
        assertEquals(42L, msg.seq)

        val payload = msg.payload
        assertIs<MlsChatResetRequestedEvent>(payload)
        assertEquals("100", payload.cursor)
        assertEquals("convo-abc", payload.convoId)
        assertEquals("csess-123", payload.cryptoSessionId)
        assertEquals(7, payload.generation)
        assertEquals("quorum", payload.trigger)
        assertEquals("evt-9001", payload.requestEventId)
        assertEquals("grp-future-xyz", payload.expectedNewMlsGroupId)
        assertEquals("epoch spiral", payload.reason)
        assertEquals("2026-04-28T10:11:12Z", payload.requestedAt)
    }

    @Test
    fun resetRequestedEventMinimalPayloadParses() {
        // Lexicon allows expectedNewMlsGroupId / reason / requestedAt to be omitted.
        // Verify the parser tolerates absence and leaves the optionals null.
        val frame = """
            {
              "t": "event",
              "payload": {
                "${'$'}type": "blue.catbird.mlsChat.subscribeEvents#resetRequestedEvent",
                "cursor": "200",
                "convoId": "convo-min",
                "cryptoSessionId": "csess-min",
                "generation": 1,
                "trigger": "system_sweep",
                "requestEventId": "evt-min"
              }
            }
        """.trimIndent()

        val msg = parseRealtimeMessage(frame)
        assertIs<MlsChatRealtimeMessage.Event>(msg)
        val payload = msg.payload
        assertIs<MlsChatResetRequestedEvent>(payload)
        assertEquals("convo-min", payload.convoId)
        assertEquals(1, payload.generation)
        assertEquals("system_sweep", payload.trigger)
        assertNull(payload.expectedNewMlsGroupId)
        assertNull(payload.reason)
        assertNull(payload.requestedAt)
    }

    @Test
    fun unknownEventDiscriminatorFallsThroughToUnknown() {
        // Regression gate: an event type the parser does not recognise must
        // surface as MlsChatRealtimeMessage.Unknown rather than crashing or
        // silently being treated as a known event.
        val frame = """
            {
              "t": "event",
              "seq": 5,
              "payload": {
                "${'$'}type": "blue.catbird.mlsChat.subscribeEvents#nonExistentEvent",
                "cursor": "300",
                "convoId": "convo-xyz"
              }
            }
        """.trimIndent()

        val msg = parseRealtimeMessage(frame)
        assertIs<MlsChatRealtimeMessage.Unknown>(msg)
        assertEquals(5L, msg.seq)
    }

    @Test
    fun groupResetEventDoesNotRouteToResetRequestedEvent() {
        // Cross-contamination gate: the existing `#groupResetEvent` discriminator
        // must NOT be claimed by the new resetRequestedEvent dispatch case. (The
        // existing groupResetEvent decode path has a pre-existing latent issue —
        // missing `@Serializable` on the bridge class — so it falls through to
        // Unknown rather than producing a typed payload. The point of THIS test
        // is to ensure the new dispatch case did not steal the routing.)
        val frame = """
            {
              "t": "event",
              "payload": {
                "${'$'}type": "blue.catbird.mlsChat.subscribeEvents#groupResetEvent",
                "cursor": "400",
                "convoId": "convo-grp",
                "newGroupId": "grp-new",
                "resetGeneration": 2
              }
            }
        """.trimIndent()

        val msg = parseRealtimeMessage(frame)
        // Must not be the new event, regardless of whether it parses to
        // MlsChatGroupResetEvent or falls through to Unknown.
        when (msg) {
            is MlsChatRealtimeMessage.Event -> assertTrue(
                msg.payload !is MlsChatResetRequestedEvent,
                "groupResetEvent payload must not be routed to MlsChatResetRequestedEvent"
            )
            is MlsChatRealtimeMessage.Unknown -> { /* acceptable: pre-existing latent bug */ }
            is MlsChatRealtimeMessage.Error -> error("Unexpected Error: ${msg.error} ${msg.message}")
        }
    }
}
