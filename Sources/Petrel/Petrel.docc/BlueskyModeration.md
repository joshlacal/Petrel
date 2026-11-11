# Labels and Moderation

Decide how to show posts, profiles and other content from labels, mutes, blocks and the user's settings, and choose which labelers a client listens to.

## Overview

Moderation in Bluesky is applied by the client. The AppView attaches labels and viewer state (mutes, blocks) to what it returns; the client combines those with the user's preferences and decides what to hide, cover or annotate. ``Moderation`` is a port of the decision engine of the official client: the same inputs give the same decisions, and the reference test suites run against it. There is one deliberate difference in muted-word matching: a word containing `/`, such as a link or `and/or`, is skipped on its own, where the reference stops checking the rest of the text and so misses muted words that come after it.

Every example on this page is compiled and run by `Tests/PetrelTests/ModerationDocExampleTests.swift` or `Tests/PetrelTests/BskyDocumentationExampleTests.swift`.

### Decide how to show a post

A decision is made once per subject and then asked about each place the subject appears. ``ModerationDecision/ui(_:)`` answers for one context: `.contentList` for a post in a feed, `.contentView` for the opened post, `.contentMedia` for its images, `.avatar`, `.profileList` and so on.

```swift
let prefs = ModerationPrefs(
    adultContentEnabled: true,
    labels: ["porn": .warn],
    labelers: [ModerationPrefsLabeler(did: bskyLabeler)],
    mutedWords: [AppBskyActorDefs.MutedWord(value: "spoilers", targets: [.content], actorTarget: "all")]
)
let options = ModerationOptions(userDid: viewer, prefs: prefs)

let decision = Moderation.moderatePost(post, options: options)

// In a feed: leave filtered posts out, cover blurred ones.
let inFeed = decision.ui(.contentList)
if inFeed.filter { /* leave it out of the feed */ }
if inFeed.blur { /* cover it; offer "Show" unless inFeed.noOverride */ }

// Media is decided separately from the post body.
let media = decision.ui(.contentMedia)
if media.blur { /* cover images; locked when media.noOverride */ }

// Say why, from the causes behind the decision.
for cause in inFeed.blurs + media.blurs {
    switch cause.kind {
    case let .label(label): reasons.append("Labeled \(label.labelDef.identifier)")
    case let .muteWord(matches): reasons.append("Muted word: \(matches.map(\.word.value).joined(separator: ", "))")
    case .muted: reasons.append("Muted account")
    case .blocking, .blockedBy, .blockOther: reasons.append("Blocked")
    case .hidden: reasons.append("Hidden by you")
    }
}
```

A ``ModerationUI`` has four outcomes: `filter` (leave the item out of a listing), `blur` (cover it; `noOverride` means the user may not uncover it), `alert` and `inform` (show it with a strong or mild notice). ``Moderation`` also has `moderateProfile`, `moderateNotification`, `moderateFeedGenerator`, `moderateUserList` and `moderateStatus`.

### Get the options from the account

In an app the options come from the signed-in account rather than from literals. ``BskyAgent/moderationOptions()`` reads the user's preferences and fetches the label definitions published by the labelers they subscribe to.

```swift
// The user's DID, moderation preferences and their labelers' label
// definitions. Fetch once and reuse until preferences change.
let options = try await bsky.moderationOptions()

let decision = Moderation.moderatePost(post, options: options)
let inFeed = decision.ui(.contentList)
if inFeed.filter {
    return "leave it out of the feed"
} else if inFeed.blur {
    return inFeed.noOverride ? "cover it for good" : "cover it behind a Show button"
} else if inFeed.alert || inFeed.inform {
    return "show it with a notice"
}
return "show it"
```

Labelers define their own label values. ``Moderation/interpretLabelValueDefinitions(_:)`` turns a labeler's published definitions into the form the engine uses; `moderationOptions()` does this for you. Label values the engine has no definition for are ignored, and so are labels from sources the user has not subscribed to.

### Choose which labelers to listen to

A service only attaches labels from the labelers a request names in the `atproto-accept-labelers` header. Reading preferences with ``BskyAgent/getPreferences()`` sets that header from the user's subscriptions, after the app labelers (by default the Bluesky moderation service, with the `redact` flag). You can also set it directly:

```swift
let ozone = try DID(didString: "did:plc:ar7c4by46qjdydhdevvrndac")
let community = try DID(didString: "did:web:labeler.example.com")

// Ask for labels from these services on every request.
await client.configureLabelers([
    AcceptedLabeler(did: ozone, redact: true),
    AcceptedLabeler(did: community),
])

// An empty list means "apply no labels". To return to the server's
// defaults, remove the header instead.
await client.configureLabelers([])
await client.clearLabelers()
```

### Report to a labeler, or send any call to a specific service

Proxying is chosen per call. Nothing is written to the client's shared headers, so a report addressed to one labeler does not affect the requests that follow.

```swift
// The report goes to this labeler for this request only.
try await bsky.createModerationReport(
    ComAtprotoModerationCreateReport.Input(
        reasonType: .comatprotomoderationdefsreasonspam,
        reason: "Repeated unsolicited replies",
        subject: .comAtprotoAdminDefsRepoRef(.init(did: account))
    ),
    labeler: labeler
)

// Any lexicon method can be sent to a specific service the same way.
let convos = try await bsky.query(
    "chat.bsky.convo.listConvos",
    parameters: ChatBskyConvoListConvos.Parameters(limit: 20),
    as: ChatBskyConvoListConvos.Output.self,
    options: BskyCallOptions(proxy: .bskyChat)
)
```

### Consume a label stream

Labels read straight from a labeler (`com.atproto.label.subscribeLabels` or `queryLabels`) include negations and expired labels, which must not be applied. ``LabelSet`` keeps the latest label per source, subject and value and returns only the ones in force. ``LabelStreamDecoder`` decodes raw stream frames and skips the frames a client is required to ignore.

```swift
var labels = LabelSet()
for frame in frames {
    // Frames with a message type this SDK does not know decode to nil
    // and are skipped; the stream goes on.
    try labels.apply(LabelStreamDecoder.decode(frame: frame))
}
// Negated and expired labels are not returned. `labels.cursor` is
// where to resume the subscription.
return labels.activeLabels()
```

Label signatures are not verified by this API. Labels hydrated by an AppView have already been validated by it.

## Topics

### Decisions

- ``Moderation``
- ``ModerationOptions``
- ``ModerationDecision``
- ``ModerationUI``
- ``ModerationCause``
- ``ModerationCauseSource``
- ``ModerationBehavior``
- ``MuteWordMatch``

### Label definitions

- ``KnownLabels``
- ``InterpretedLabelValueDefinition``
- ``LabelPreference``
- ``LabelTarget``
- ``LabelValueDefinitionFlag``

### Preferences

- ``ModerationPrefs``
- ``ModerationPrefsLabeler``

### Subjects

- ``ModerationSubjectProfile``
- ``ModerationSubjectUserList``

### Labelers and proxying

- ``AcceptedLabeler``
- ``ServiceProxy``
- ``BskyCallOptions``

### Label streams

- ``LabelSet``
- ``LabelStreamEvent``
- ``LabelStreamDecoder``
