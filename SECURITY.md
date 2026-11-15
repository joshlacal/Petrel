# Security Policy (`Petrel`)

## Reporting a Vulnerability

**Do not open a public GitHub issue or pull request for security vulnerabilities.**

1. **GitHub Private Vulnerability Reporting (Preferred):** Report privately at `https://github.com/joshlacal/Petrel/security/advisories/new`.
2. **Email Fallback:** Email **`security@catbird.blue`** with the repository name, commit SHA, affected invariant (`I1`–`I16`), and minimal reproduction steps.

## Coordinated Disclosure Policy

- **Acknowledgement:** Within 48 hours.
- **Triage:** Within 5 business days.
- **Coordinated Embargo:** Up to 90 days for cryptographic (`MLS 0x004D X-Wing`, `Labyrinth Hawk HPKE / DNDK-GCM / CPace+ML-KEM-768`, `I13` receipts, `atproto-spaces` RFC 9421 / HPKE Export MACs), client-storage (`SQLCipher` / `sqlite3mc` OPFS), or federation vulnerabilities so client app-store updates and self-hosted server operators can upgrade safely before proof-of-concept details are published.

## Licensing

Dual-licensed under `MIT OR Apache-2.0` (`LICENSE-MIT` and `LICENSE-APACHE`), at your option.
