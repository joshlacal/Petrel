**[ 🚧 UNDER CONSTRUCTION 🏗️ ]**

# ``Petrel``

Petrel is a Swift library for the ATProtocol and Bluesky.


## Overview

A Python script creates the data model and networking code from the Lexicon JSON files provided by Bluesky using jinja templates.

For the most part, there is a 1:1 Lexicon to Swift file translation. Data models are converted into CamelCase; e.g., an `app.bsky.feed.post` record converts to `AppBskyFeedPost` in Swift. Procedure and query lexicons endpoints are available as function calls from the base client class, `ATProtoClient`, and are namespaced using instance properties; for example, the `com.atproto.repo.createRecord` XRPC endpoint is available at `ATProtoClient.com.atproto.repo.createRecord()` (and takes a `ComAtprotoRepoCreateRecord.Input` struct).



License

MIT
