# ``PetrelPLCPDS``

Change a `did:plc` identity through the PDS that hosts the account.

## Overview

Most accounts do not hold a rotation key for their own identity: the PDS
does. The PDS will sign a PLC operation for the account once the account
holder confirms by email, through four `com.atproto.identity` procedures.
``PLCPDSOperationFlow`` drives them with the generated `Petrel` client and
returns `PetrelPLC` values, so that what the PDS signed can be verified
before it is submitted.

```swift
import Petrel
import PetrelPLC
import PetrelPLCPDS

let flow = PLCPDSOperationFlow(api: await client.com.atproto.identity)
let directory = try PLCDirectoryClient()

// 1. The PDS emails the account holder a token.
try await flow.requestSignatureToken()

// 2. Ask the PDS to sign an operation that puts a key you hold first.
let current = try await directory.fetchVerifiedAuditLog(did: did)
let currentKeys = current.documentData?.rotationKeys ?? []
let operation = try await flow.signOperation(
    token: tokenFromEmail,
    changing: PLCPDSOperationFields(rotationKeys: [myRecoveryKey.didKey] + currentKeys)
)

// 3. Check what was signed against the verified log.
try current.verifyNextOperation(operation)

// 4. Submit it through the PDS.
try await flow.submit(operation)
```

Once a key of your own is in `rotationKeys`, later changes can be signed
and submitted directly with `PLCDirectoryClient`.

## Topics

### Flow

- ``PLCPDSOperationFlow``
- ``PLCPDSOperationFields``
- ``PLCPDSFlowError``

### Bridging

- ``PLCPDSIdentityAPI``
- ``PLCPDSBridge``
