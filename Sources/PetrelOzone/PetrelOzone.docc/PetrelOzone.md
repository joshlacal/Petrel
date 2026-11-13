# ``PetrelOzone``

Typed Swift API for the `tools.ozone` moderation-service Lexicons.

## Overview

`PetrelOzone` adds the `tools.ozone.*` namespace to Petrel's `ATProtoClient`:
moderation events and subject statuses, report queues, team management, sets,
safelinks, verification and the rest of the Ozone API. It is a separate product
so that applications which do not run or operate a moderation service do not
carry it.

<!-- compile-example: ozone-query-statuses -->
```swift
import Petrel
import PetrelOzone

/// Call once at startup: lets `tools.ozone` types decode inside untyped data.
func registerOzone() {
    PetrelOzoneLexicons.register()
}

func openReports(
    client: ATProtoClient,
    ozoneService: String
) async throws -> ToolsOzoneModerationQueryStatuses.Output? {
    // Proxy every tools.ozone call to your moderation service,
    // given as a DID service reference such as "did:plc:…#atproto_labeler".
    await client.setServiceDID(ozoneService, for: "tools.ozone")

    let (_, statuses) = try await client.tools.ozone.moderation.queryStatuses(
        input: .init(reviewState: "tools.ozone.moderation.defs#reviewOpen", limit: 50)
    )
    return statuses
}
```

Without a service set for `tools.ozone`, calls go to the account's PDS
unproxied. Set the service once with `ATProtoClient.setServiceDID(_:for:)`, as
above, or per call with `XRPCCallOptions.proxy`. Errors, per-call options and
response metadata behave as for every other generated call (see "Calling XRPC
Endpoints" in the Petrel documentation).

The module is generated from `generator/lexicons/tools` with the same generator
and overlay manifest (`generator/manifests/petrel-ozone.json`) third parties
use for their own Lexicons.
