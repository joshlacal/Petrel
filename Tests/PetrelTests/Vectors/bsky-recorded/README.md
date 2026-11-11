# Recorded AppView responses

Responses of the public Bluesky AppView (`https://public.api.bsky.app`), recorded
on 2026-11-11 and stored as returned, re-indented, with one omission: the
profile's transient `status` entry (a live-stream pointer) was removed. They
describe Bluesky's own service accounts only.

| File | Request |
|---|---|
| `labeler-services.json` | `app.bsky.labeler.getServices?dids=did:plc:ar7c4by46qjdydhdevvrndac&detailed=true` (the Bluesky moderation service and its label definitions) |
| `profile.json` | `app.bsky.actor.getProfile?actor=bsky.app` |

`Tests/PetrelTests/BskyRecordedFixtureTests.swift` decodes them with the
generated types and runs the label-definition interpreter and the moderation
engine over them, so those helpers are checked against data a real service
produced and not only against hand-built values.
