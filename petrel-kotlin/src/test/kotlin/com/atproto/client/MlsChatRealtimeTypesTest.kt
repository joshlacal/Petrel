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
        // must NOT be claimed by the new resetRequestedEvent dispatch case.
        //
        // PRE-FIX: this test tolerated `Unknown` because `MlsChatGroupResetEvent`
        // was missing `@Serializable` and silently fell through. POST-FIX (this
        // PR): the bridge class is annotated, so the assertion is inverted —
        // `MlsChatGroupResetEvent` must be produced, not Unknown.
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
        assertIs<MlsChatRealtimeMessage.Event>(msg)
        val payload = msg.payload
        // assertIs alone is sufficient cross-contamination evidence — once the
        // payload is statically `MlsChatGroupResetEvent`, it provably is not
        // `MlsChatResetRequestedEvent`.
        assertIs<MlsChatGroupResetEvent>(payload)
    }

    // MARK: - Bridge-class @Serializable regression tests
    //
    // These tests guard the PR-#7 follow-up cleanup that added `@Serializable`
    // to every hand-written bridge class. Before that fix, every event below
    // silently fell through to `MlsChatRealtimeMessage.Unknown` because
    // `realtimeJson.decodeFromJsonElement<T>` cannot synthesize a serializer
    // for a non-`@Serializable` data class — the runtime exception was caught
    // by `parseRealtimeEvent`'s broad `catch` and the event was dropped.
    //
    // `MlsChatGroupResetEvent` is the highest-priority case (epoch-spiral
    // recovery on Android) and gets the deepest coverage; the rest get a
    // single positive parse to confirm the annotation took effect.

    @Test
    fun groupResetEventFullPayloadParses() {
        val frame = """
            {
              "t": "event",
              "seq": 99,
              "payload": {
                "${'$'}type": "blue.catbird.mlsChat.subscribeEvents#groupResetEvent",
                "cursor": "501",
                "convoId": "convo-reset",
                "newGroupId": "grp-new-id",
                "resetGeneration": 3,
                "resetBy": "did:plc:resetter",
                "cipherSuite": "MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519",
                "reason": "epoch spiral recovery"
              }
            }
        """.trimIndent()

        val msg = parseRealtimeMessage(frame)
        assertIs<MlsChatRealtimeMessage.Event>(msg)
        assertEquals(99L, msg.seq)
        val payload = msg.payload
        assertIs<MlsChatGroupResetEvent>(payload)
        assertEquals("501", payload.cursor)
        assertEquals("convo-reset", payload.convoId)
        assertEquals("grp-new-id", payload.newGroupId)
        assertEquals(3, payload.resetGeneration)
        assertEquals("did:plc:resetter", payload.resetBy)
        assertEquals(
            "MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519",
            payload.cipherSuite
        )
        assertEquals("epoch spiral recovery", payload.reason)
    }

    @Test
    fun groupResetEventMinimalPayloadParses() {
        // resetBy / cipherSuite / reason are optional in the lexicon.
        val frame = """
            {
              "t": "event",
              "payload": {
                "${'$'}type": "blue.catbird.mlsChat.subscribeEvents#groupResetEvent",
                "cursor": "502",
                "convoId": "convo-min",
                "newGroupId": "grp-min",
                "resetGeneration": 1
              }
            }
        """.trimIndent()

        val msg = parseRealtimeMessage(frame)
        assertIs<MlsChatRealtimeMessage.Event>(msg)
        val payload = msg.payload
        assertIs<MlsChatGroupResetEvent>(payload)
        assertEquals("convo-min", payload.convoId)
        assertEquals("grp-min", payload.newGroupId)
        assertEquals(1, payload.resetGeneration)
        assertNull(payload.resetBy)
        assertNull(payload.cipherSuite)
        assertNull(payload.reason)
    }

    @Test
    fun groupResetEventDoesNotRouteToResetRequestedEventInverse() {
        // Inverse of `resetRequestedEventFullPayloadParses` — the new
        // `#resetRequestedEvent` dispatch must not catch `groupResetEvent`
        // payloads, even now that both decode through `decodeFromJsonElement`.
        val frame = """
            {
              "t": "event",
              "payload": {
                "${'$'}type": "blue.catbird.mlsChat.subscribeEvents#resetRequestedEvent",
                "cursor": "503",
                "convoId": "convo-x",
                "cryptoSessionId": "csess-x",
                "generation": 4,
                "trigger": "inline_409",
                "requestEventId": "evt-x"
              }
            }
        """.trimIndent()

        val msg = parseRealtimeMessage(frame)
        assertIs<MlsChatRealtimeMessage.Event>(msg)
        assertTrue(
            msg.payload !is MlsChatGroupResetEvent,
            "resetRequestedEvent payload must not be routed to MlsChatGroupResetEvent"
        )
    }

    @Test
    fun reactionEventParses() {
        val frame = """
            {
              "t": "event",
              "payload": {
                "${'$'}type": "blue.catbird.mlsChat.subscribeEvents#reactionEvent",
                "cursor": "601",
                "convoId": "convo-r",
                "messageId": "msg-r",
                "did": "did:plc:reactor",
                "emoji": "U+1F44D",
                "reaction": "thumbs_up",
                "action": "added"
              }
            }
        """.trimIndent()

        val msg = parseRealtimeMessage(frame)
        assertIs<MlsChatRealtimeMessage.Event>(msg)
        val payload = msg.payload
        assertIs<MlsChatReactionEvent>(payload)
        assertEquals("convo-r", payload.convoId)
        assertEquals("msg-r", payload.messageId)
        assertEquals("thumbs_up", payload.reaction)
        assertEquals("added", payload.action)
    }

    @Test
    fun typingEventParses() {
        val frame = """
            {
              "t": "event",
              "payload": {
                "${'$'}type": "blue.catbird.mlsChat.subscribeEvents#typingEvent",
                "cursor": "701",
                "convoId": "convo-t",
                "did": "did:plc:typer",
                "isTyping": true
              }
            }
        """.trimIndent()

        val msg = parseRealtimeMessage(frame)
        assertIs<MlsChatRealtimeMessage.Event>(msg)
        val payload = msg.payload
        assertIs<MlsChatTypingEvent>(payload)
        assertEquals("convo-t", payload.convoId)
        assertEquals(true, payload.isTyping)
    }

    @Test
    fun infoEventParses() {
        val frame = """
            {
              "t": "event",
              "payload": {
                "${'$'}type": "blue.catbird.mlsChat.subscribeEvents#infoEvent",
                "cursor": "801",
                "info": "heartbeat",
                "convoId": "convo-i",
                "infoType": "system",
                "requestedBy": "did:plc:requester"
              }
            }
        """.trimIndent()

        val msg = parseRealtimeMessage(frame)
        assertIs<MlsChatRealtimeMessage.Event>(msg)
        val payload = msg.payload
        assertIs<MlsChatInfoEvent>(payload)
        assertEquals("heartbeat", payload.info)
        assertEquals("convo-i", payload.convoId)
        assertEquals("system", payload.infoType)
        assertEquals("did:plc:requester", payload.requestedBy)
    }

    @Test
    fun readEventParses() {
        val frame = """
            {
              "t": "event",
              "payload": {
                "${'$'}type": "blue.catbird.mlsChat.subscribeEvents#readEvent",
                "cursor": "901",
                "convoId": "convo-rd",
                "did": "did:plc:reader",
                "messageId": "msg-rd"
              }
            }
        """.trimIndent()

        val msg = parseRealtimeMessage(frame)
        assertIs<MlsChatRealtimeMessage.Event>(msg)
        val payload = msg.payload
        assertIs<MlsChatReadEvent>(payload)
        assertEquals("convo-rd", payload.convoId)
        assertEquals("msg-rd", payload.messageId)
    }

    @Test
    fun newDeviceEventParses() {
        val frame = """
            {
              "t": "event",
              "payload": {
                "${'$'}type": "blue.catbird.mlsChat.subscribeEvents#newDeviceEvent",
                "cursor": "1001",
                "convoId": "convo-nd",
                "userDid": "did:plc:owner",
                "deviceId": "dev-1",
                "deviceName": "iPhone"
              }
            }
        """.trimIndent()

        val msg = parseRealtimeMessage(frame)
        assertIs<MlsChatRealtimeMessage.Event>(msg)
        val payload = msg.payload
        assertIs<MlsChatNewDeviceEvent>(payload)
        assertEquals("convo-nd", payload.convoId)
        assertEquals("did:plc:owner", payload.userDid)
        assertEquals("dev-1", payload.deviceId)
        assertEquals("iPhone", payload.deviceName)
    }

    @Test
    fun membershipChangeEventParses() {
        val frame = """
            {
              "t": "event",
              "payload": {
                "${'$'}type": "blue.catbird.mlsChat.subscribeEvents#membershipChangeEvent",
                "cursor": "1101",
                "convoId": "convo-mc",
                "did": "did:plc:newcomer",
                "action": "joined"
              }
            }
        """.trimIndent()

        val msg = parseRealtimeMessage(frame)
        assertIs<MlsChatRealtimeMessage.Event>(msg)
        val payload = msg.payload
        assertIs<MlsChatMembershipChangeEvent>(payload)
        assertEquals("convo-mc", payload.convoId)
        assertEquals("did:plc:newcomer", payload.did)
        assertEquals("joined", payload.action)
    }

    @Test
    fun groupInfoRefreshRequestedEventParses() {
        // Lexicon-canonical discriminator is `#groupInfoRefreshRequestedEvent`.
        val frame = """
            {
              "t": "event",
              "payload": {
                "${'$'}type": "blue.catbird.mlsChat.subscribeEvents#groupInfoRefreshRequestedEvent",
                "cursor": "1201",
                "convoId": "convo-gi"
              }
            }
        """.trimIndent()

        val msg = parseRealtimeMessage(frame)
        assertIs<MlsChatRealtimeMessage.Event>(msg)
        val payload = msg.payload
        assertIs<MlsChatGroupInfoRefreshRequestedEvent>(payload)
        assertEquals("convo-gi", payload.convoId)
    }

    @Test
    fun readditionRequestedEventParses() {
        // Lexicon-canonical discriminator is `#readditionRequestedEvent`.
        val frame = """
            {
              "t": "event",
              "payload": {
                "${'$'}type": "blue.catbird.mlsChat.subscribeEvents#readditionRequestedEvent",
                "cursor": "1301",
                "convoId": "convo-rr",
                "userDid": "did:plc:rejoiner"
              }
            }
        """.trimIndent()

        val msg = parseRealtimeMessage(frame)
        assertIs<MlsChatRealtimeMessage.Event>(msg)
        val payload = msg.payload
        assertIs<MlsChatReadditionRequestedEvent>(payload)
        assertEquals("convo-rr", payload.convoId)
        assertEquals("did:plc:rejoiner", payload.userDid)
    }
}
