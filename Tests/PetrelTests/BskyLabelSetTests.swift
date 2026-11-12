import Foundation
import Petrel
import SwiftCBOR
import Testing

private let labeler = "did:plc:labeler"
private let post = "at://did:plc:bob/app.bsky.feed.post/3kpost"

private func label(
    _ val: String,
    uri: String = post,
    src: String = labeler,
    at seconds: TimeInterval,
    neg: Bool? = nil,
    exp: TimeInterval? = nil
) throws -> ComAtprotoLabelDefs.Label {
    try ComAtprotoLabelDefs.Label(
        ver: 1,
        src: DID(didString: src),
        uri: URI(uriString: uri),
        val: val,
        neg: neg,
        cts: ATProtocolDate(date: Date(timeIntervalSince1970: seconds)),
        exp: exp.map { ATProtocolDate(date: Date(timeIntervalSince1970: $0)) }
    )
}

private let now = Date(timeIntervalSince1970: 1000)

@Suite("Label lifecycle")
struct BskyLabelSetTests {
    @Test("a label is active unless negated or expired")
    func isActive() throws {
        #expect(try label("spam", at: 1).isActive(at: now))
        #expect(try !label("spam", at: 1, neg: true).isActive(at: now))
        #expect(try label("spam", at: 1, neg: false).isActive(at: now))
        #expect(try label("spam", at: 1, exp: 2000).isActive(at: now))
        #expect(try !label("spam", at: 1, exp: 1000).isActive(at: now))
        #expect(try !label("spam", at: 1, exp: 500).isActive(at: now))
        #expect(try label("spam", at: 1, exp: 500).isExpired(at: now))
        #expect(try label("spam", at: 1, neg: true).isNegation)
    }

    @Test("a negation retracts the earlier label with the same source, subject and value")
    func negation() throws {
        var labels = LabelSet()
        try labels.apply(label("spam", at: 10))
        try labels.apply(label("rude", at: 10))
        #expect(labels.activeLabels(for: post, at: now).map(\.val) == ["rude", "spam"])

        try labels.apply(label("spam", at: 20, neg: true))
        #expect(labels.activeLabels(for: post, at: now).map(\.val) == ["rude"])

        // A negation only retracts its own (source, subject, value).
        try labels.apply(label("rude", src: "did:plc:other", at: 30, neg: true))
        try labels.apply(label("rude", uri: "did:plc:bob", at: 30, neg: true))
        #expect(labels.activeLabels(for: post, at: now).map(\.val) == ["rude"])
    }

    @Test("a re-issued label is active again; an older replay does not undo a negation")
    func ordering() throws {
        var labels = LabelSet()
        try labels.apply(label("spam", at: 10))
        try labels.apply(label("spam", at: 20, neg: true))
        // The stream replays the original label after the negation.
        #expect(try labels.apply(label("spam", at: 10)) == false)
        #expect(labels.activeLabels(at: now).isEmpty)

        #expect(try labels.apply(label("spam", at: 30)) == true)
        #expect(labels.activeLabels(at: now).map(\.val) == ["spam"])
    }

    @Test("expired labels stop being active as time passes")
    func expiry() throws {
        var labels = LabelSet()
        try labels.apply(label("spam", at: 10, exp: 1500))
        #expect(labels.activeLabels(at: now).count == 1)
        #expect(labels.activeLabels(at: Date(timeIntervalSince1970: 1500)).isEmpty)
    }

    @Test("stream events advance the cursor; info events do not")
    func cursor() throws {
        var labels = LabelSet()
        #expect(labels.cursor == nil)
        try labels.apply(LabelStreamEvent.labels(seq: 41, labels: [label("spam", at: 10)]))
        labels.apply(LabelStreamEvent.info(name: "OutdatedCursor", message: nil))
        labels.apply(LabelStreamEvent?.none)
        #expect(labels.cursor == 41)
        #expect(labels.activeLabels(at: now).count == 1)
    }

    @Test("prune drops old tombstones and expired labels but keeps recent ones")
    func prune() throws {
        var labels = LabelSet()
        try labels.apply(label("old", at: 10, neg: true))
        try labels.apply(label("recent", at: 900, neg: true))
        try labels.apply(label("kept", at: 10))
        labels.prune(at: now, olderThan: Date(timeIntervalSince1970: 500))

        // The old tombstone is gone, so a replay of that label is taken again…
        #expect(try labels.apply(label("old", at: 5)) == true)
        // …while the recent one still blocks its replay.
        #expect(try labels.apply(label("recent", at: 800)) == false)
        #expect(labels.activeLabels(at: now).map(\.val) == ["kept", "old"])
    }
}

@Suite("subscribeLabels frames")
struct BskyLabelStreamDecoderTests {
    private func frame(header: [CBOR: CBOR], payload: CBOR) -> Data {
        Data(CBOR.map(header).encode() + payload.encode())
    }

    private func labelsPayload(seq: UInt64) -> CBOR {
        .map([
            "seq": .unsignedInt(seq),
            "labels": .array([
                .map([
                    "ver": 1,
                    "src": .utf8String(labeler),
                    "uri": .utf8String(post),
                    "val": "spam",
                    "cts": "2024-01-01T00:00:00.000Z",
                    "sig": .byteString([1, 2, 3]),
                ]),
                .map([
                    "ver": 1,
                    "src": .utf8String(labeler),
                    "uri": .utf8String(post),
                    "val": "rude",
                    "neg": true,
                    "cts": "2024-01-02T00:00:00.000Z",
                ]),
            ]),
        ])
    }

    @Test("a #labels frame decodes to its sequence number and labels")
    func labelsFrame() throws {
        let data = frame(header: ["op": 1, "t": "#labels"], payload: labelsPayload(seq: 42))
        guard case let .labels(seq, labels)? = try LabelStreamDecoder.decode(frame: data) else {
            Issue.record("expected a labels event")
            return
        }
        #expect(seq == 42)
        #expect(labels.map(\.val) == ["spam", "rude"])
        #expect(labels.map(\.isNegation) == [false, true])
        #expect(labels[0].src.didString() == labeler)
        #expect(labels[0].sig?.data == Data([1, 2, 3]))
    }

    @Test("an #info frame decodes to its name and message")
    func infoFrame() throws {
        let data = frame(
            header: ["op": 1, "t": "#info"],
            payload: ["name": "OutdatedCursor", "message": "Requested cursor exceeded limit"]
        )
        #expect(try LabelStreamDecoder.decode(frame: data)
            == .info(name: "OutdatedCursor", message: "Requested cursor exceeded limit"))
    }

    @Test("frames with an unknown message type or operation are ignored, not errors")
    func unknownFramesAreIgnored() throws {
        let unknownType = frame(header: ["op": 1, "t": "#somethingNew"], payload: ["x": 1])
        #expect(try LabelStreamDecoder.decode(frame: unknownType) == nil)

        let unknownOp = frame(header: ["op": 2, "t": "#labels"], payload: labelsPayload(seq: 1))
        #expect(try LabelStreamDecoder.decode(frame: unknownOp) == nil)

        let unknownNegativeOp = frame(header: ["op": .negativeInt(4)], payload: [:])
        #expect(try LabelStreamDecoder.decode(frame: unknownNegativeOp) == nil)
    }

    @Test("a stream keeps its state across frames it must ignore")
    func consumerSurvivesUnknownFrames() throws {
        var labels = LabelSet()
        let frames = [
            frame(header: ["op": 1, "t": "#labels"], payload: labelsPayload(seq: 1)),
            frame(header: ["op": 1, "t": "#somethingNew"], payload: ["x": 1]),
            frame(header: ["op": 7, "t": "#labels"], payload: [:]),
            frame(header: ["op": 1, "t": "#info"], payload: ["name": "OutdatedCursor"]),
            frame(header: ["op": 1, "t": "#labels"], payload: labelsPayload(seq: 2)),
        ]
        for data in frames {
            try labels.apply(LabelStreamDecoder.decode(frame: data))
        }
        #expect(labels.cursor == 2)
        #expect(labels.activeLabels(at: Date()).map(\.val) == ["spam"])
    }

    @Test("an error frame and malformed framing throw")
    func hardErrors() {
        let errorFrame = frame(header: ["op": .negativeInt(0)], payload: ["error": "FutureCursor"])
        #expect(throws: (any Error).self) { try LabelStreamDecoder.decode(frame: errorFrame) }

        for malformed in [Data(), Data([0xFF, 0x00]), Data(CBOR.utf8String("not a map").encode())] {
            #expect(throws: (any Error).self) { try LabelStreamDecoder.decode(frame: malformed) }
        }
        let noOp = frame(header: ["t": "#labels"], payload: [:])
        #expect(throws: (any Error).self) { try LabelStreamDecoder.decode(frame: noOp) }
        let noType = frame(header: ["op": 1], payload: [:])
        #expect(throws: (any Error).self) { try LabelStreamDecoder.decode(frame: noType) }
        // A known type whose payload does not match the lexicon is an error too.
        let badPayload = frame(header: ["op": 1, "t": "#labels"], payload: ["seq": "not a number"])
        #expect(throws: (any Error).self) { try LabelStreamDecoder.decode(frame: badPayload) }
    }

    @Test("messages of the generated subscription convert to events")
    func fromGeneratedMessage() throws {
        let labels = try ComAtprotoLabelSubscribeLabels.Labels(seq: 9, labels: [label("spam", at: 1)])
        #expect(LabelStreamEvent(.labels(labels)) == .labels(seq: 9, labels: labels.labels))
        let info = ComAtprotoLabelSubscribeLabels.Info(name: "OutdatedCursor", message: nil)
        #expect(LabelStreamEvent(.info(info)) == .info(name: "OutdatedCursor", message: nil))
    }
}
