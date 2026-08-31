# ``Petrel``

A Swift 6 SDK for the AT Protocol and Bluesky.

## Overview

Petrel generates strongly typed, actor-based Swift APIs from the upstream
`com.atproto.*`, `app.bsky.*`, and `chat.bsky.*` lexicons. Calls are made
through ``ATProtoClient``, which owns authentication, networking, and account
state.

Authentication covers OAuth with PAR, PKCE, and DPoP; a confidential gateway
mode; a client-assertion backend mode; and a legacy app-password path retained
for existing integrations. New applications should use OAuth.

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Authentication>

### Core Components

- ``ATProtoClient``

The client encapsulates authentication, networking, and account management. You typically do not interact with
the internal services directly.

### Identifier and Record Utilities

- ``TIDGenerator``
