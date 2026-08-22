# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See [AGENTS.md](AGENTS.md) for the complete, canonical guide to Petrel's architecture, code generation pipeline, calling shapes, and release policies.

## Quick Reference

| Task | Command |
|---|---|
| Build | `swift build` |
| Test | `swift test` |
| Test single suite | `swift test --filter <TestName>` |
| Regenerate code | `python3 run.py --manifest generator/manifests/petrel-core.json && swiftformat Sources/Petrel/Generated` |

## Key Rules for AI Coding

- **Never edit generated code by hand**: `Sources/Petrel/Generated/` is managed by the generator. Modify templates in `generator/templates/` or schemas in `generator/lexicons/` instead.
- **Code generation**: Run `python3 run.py --manifest generator/manifests/petrel-core.json` followed by `swiftformat Sources/Petrel/Generated`.
- **Formatting**: 4-space indentation per `Petrel/.swiftformat`. Do not pass `--config ../Petrel/.swiftformat` to overlay packages.
- **CAB Server**: `Server/` is a separate SPM package (`petrel-cab-server`). The Petrel library must never depend on it. Build and test it with `cd Server && swift test`.
- **API calls**: Generated XRPC methods take a labeled `input:` argument with strongly typed parameter instances (`ATIdentifier`, `Handle`, etc.) and return `(responseCode: Int, data: Output?)` or `Int`.
- **Concurrency**: Swift 6 strict concurrency throughout (`.swiftLanguageMode(.v6)`).
