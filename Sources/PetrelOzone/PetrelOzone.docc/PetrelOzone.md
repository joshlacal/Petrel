# ``PetrelOzone``

Typed Swift API for the `tools.ozone` moderation-service Lexicons.

## Overview

`PetrelOzone` adds the `tools.ozone.*` namespace to Petrel's `ATProtoClient`:
moderation events and subject statuses, report queues, team management, sets,
safelinks, verification and the rest of the Ozone API. It is a separate product
so that applications which do not run or operate a moderation service do not
carry it.

```swift
import Petrel
import PetrelOzone

// Once, at startup: lets tools.ozone types decode inside untyped data.
PetrelOzoneLexicons.register()

let (_, statuses) = try await client.tools.ozone.moderation.queryStatuses(
    input: .init(reviewState: "tools.ozone.moderation.defs#reviewOpen", limit: 50)
)
```

Calls go to the service the client is configured to proxy `tools.ozone` to;
set it with `NetworkService.setServiceDID(_:for:)`, or per call with
`XRPCCallOptions.proxy`. Errors, per-call options and response metadata behave
as for every other generated call (see "Calling XRPC Endpoints" in the Petrel
documentation).

The module is generated from `generator/lexicons/tools` with the same generator
and overlay manifest (`generator/manifests/petrel-ozone.json`) third parties
use for their own Lexicons.
