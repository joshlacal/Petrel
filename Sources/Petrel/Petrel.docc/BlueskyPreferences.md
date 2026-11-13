# Preferences

Read the account's Bluesky preferences as one parsed value and change them with setters that never lose another client's edits.

## Overview

Bluesky stores a user's settings (saved feeds, muted words, content filters, labeler subscriptions, thread and feed view options) as an array of loosely typed entries on the PDS. ``BskyAgent/getPreferences()`` parses that array into a ``BskyPreferences`` value with the official client's defaults filled in, and each setter performs a read-modify-write of the stored array.

<!-- compile-example: bsky-preferences-overview -->
```swift
import Foundation
import Petrel

func configureUserPreferences(client: ATProtoClient) async throws -> ModerationPrefs {
    // Read everything at once.
    let prefs = try await client.bsky.getPreferences()
    let pinnedFeeds = prefs.savedFeeds.filter(\.pinned)
    let hidesReposts = prefs.feedViewPrefs["home"]?.hideReposts ?? false
    _ = (pinnedFeeds, hidesReposts)

    // Mute a word in post text and tags for a week.
    try await client.bsky.addMutedWord(
        "spoilers",
        targets: [.content, .tag],
        expiresAt: Date().addingTimeInterval(7 * 24 * 60 * 60)
    )

    // Hide graphic media instead of warning about it.
    try await client.bsky.setContentLabelPref("graphic-media", .hide)

    // Subscribe to a labeler and tune one of its labels.
    let labeler = try DID(didString: "did:plc:ar7c4by46qjdydhdevvrndac")
    try await client.bsky.addLabeler(labeler)
    try await client.bsky.setContentLabelPref("spam", .warn, labelerDid: labeler)

    // The updated settings feed straight into moderation decisions.
    return try await client.bsky.getPreferences().moderationPrefs
}
```

### What the setters guarantee

- **Nothing is dropped.** Setters rewrite the raw stored array. Entries of a type this SDK does not know, and unknown fields inside entries it does know, are written back unchanged.
- **Concurrent setters do not overwrite each other.** All read-modify-write cycles of agents that share a client's network service are serialized, including the migration that ``BskyAgent/getPreferences()`` may perform.
- **Invalid input is rejected, not repaired.** A saved feed whose type does not match its URI, an over-long onboarding identifier and similar mistakes throw ``BskyAgentError/invalidInput(_:)``.

### Behaviour inherited from the official client

- An account that only has first-generation saved feeds is migrated to `savedFeedsPrefV2` the first time its preferences are read. Afterwards, feeds and lists are mirrored back into the old entry so older clients keep working.
- Legacy content label names are honoured: `show` reads as `ignore`; settings stored under `gore`, `nsfw` and `suggestive` apply to `graphic-media`, `porn` and `sexual`; and setting one of the new names also writes the legacy one.
- Muted words are sanitized (surrounding whitespace, one leading `#`, line breaks and zero-width characters are removed) and words saved without an identifier are given one.
- Reading preferences, and adding or removing a labeler, updates the labelers this client requests labels from. See <doc:BlueskyModeration>.

## Topics

### Reading

- ``BskyPreferences``
- ``BskyAgent/getPreferences()``

### Parsed values

- ``BskyFeedViewPreference``
- ``BskyThreadViewPreference``
- ``BskyInterestsPreference``
- ``BskyAppState``
- ``BskyLiveEventPreferences``
- ``ModerationPrefs``

### Setter inputs

- ``BskyNewSavedFeed``
- ``BskyFeedViewPreferenceUpdate``
- ``BskyAppProgressGuide``
- ``BskyLiveEventPreferencesAction``
