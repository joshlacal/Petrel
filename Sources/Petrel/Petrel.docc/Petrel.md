# ``Petrel``

A comprehensive Swift library for the AT Protocol and Bluesky social network.

## Overview

Petrel provides a complete Swift implementation of the AT Protocol APIs, enabling developers to build applications that interact with Bluesky and other AT Protocol-based services. The library features automatic code generation from Lexicon specifications, modern Swift concurrency support, and robust authentication handling.

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Authentication>
- <doc:BasicUsage>

### Core Components

- ``ATProtoClient``

The client encapsulates authentication, networking, and account management. You typically do not interact with
the internal services directly.

### Authentication & Security

- <doc:OAuthFlow>
- <doc:TokenManagement>
- ``TokenRefreshCoordinator``
- ``KeychainManager``

### Working with Records

- <doc:CreatingRecords>
- <doc:QueryingData>
- ``RichText``
- ``TIDGenerator``

### Advanced Topics

- <doc:ErrorHandling>
- <doc:Concurrency>
- ``DIDDocHandler``
- ``CID``
