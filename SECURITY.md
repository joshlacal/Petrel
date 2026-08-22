# Security policy

## Supported versions

Petrel 0.2.0 is currently a release candidate. When 0.2.0 is released, it will be the primary supported release line under `.upToNextMinor(from: "0.2.0")`.

| Version | Supported | Notes |
|---------|-----------|-------|
| 0.2.x | Yes (at release) | Active development and release candidate |
| 0.1.x | No | Superseded by 0.2.x; upgrade to 0.2.x |
| < 0.1.0 | No | Unsupported pre-release versions |

## Reporting a vulnerability

To report a security vulnerability privately, use one of the following channels:

1. **GitHub Security Advisory (preferred)**: Submit a private advisory at [https://github.com/joshlacal/Petrel/security/advisories/new](https://github.com/joshlacal/Petrel/security/advisories/new).
2. **Direct email**: Send details to `joshlacal@gmail.com` with the subject line `[Petrel Security] <Summary>`.

Do not report suspected vulnerabilities in public GitHub issues, pull requests, or public discussions.

## Information to include

To help evaluate and reproduce the issue, include:

- The vulnerability type (for example, credential exposure, token leakage, DPoP key handling flaw, or cryptographic failure).
- Affected components (for example, `KeychainManager`, `AuthManager`, `FileEncryptedStore`, `LibSecretStore`, or generated XRPC endpoints).
- The platform and environment (for example, iOS 18, macOS 15, Linux server with encrypted file storage, or Linux desktop with libsecret).
- Step-by-step reproduction steps or a minimal test case demonstrating the issue.
- Potential impact and any suggested mitigations or patches, if available.

## Response process

1. **Acknowledgment**: You will receive an acknowledgment within 3 business days of receipt.
2. **Assessment**: Maintainers will evaluate the report, verify the vulnerability, and assess affected release versions.
3. **Remediation**: A fix will be developed and tested privately.
4. **Coordinated disclosure**: Maintainers will coordinate disclosure with you before publishing a security advisory and releasing a patched version.
