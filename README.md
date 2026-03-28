# CellarKit iOS

Working title for research and scaffolding around a Wine/CrossOver/Whisky-style Windows game runtime for iPhone and iPad.

Status:
- source-backed research completed for the first pass,
- architecture docs scaffolded,
- Swift planning core + tests added.

## What this repo currently contains

### Research

- `docs/research/01-executive-summary.md`
- `docs/research/02-prior-art.md`
- `docs/research/03-platform-constraints.md`
- `docs/research/04-licensing-and-policy.md`
- `docs/research/05-source-index.md`
- `docs/research/06-open-questions.md`

### Architecture

- `docs/architecture/01-proposed-architecture.md`
- `docs/architecture/02-roadmap.md`

### Agent guidance

- `docs/agents/01-autonomous-build-plan.md`

### Swift planning core

- `Package.swift`
- `Sources/CellarCore/`
- `Tests/CellarCoreTests/`

## First-pass conclusions

- A straight macOS wrapper port is not realistic.
- A side-load / developer-signed / jailbreak-first MVP is the most credible path.
- UTM is the strongest iOS-native runtime reference.
- GameNative is the strongest mobile UX reference.
- App Store distribution for a full Windows-game storefront runner is a separate, high-risk question.

## Planning core purpose

The current Swift package is intentionally small. It models:
- distribution channels,
- JIT/execution modes,
- guest architectures,
- acquisition modes,
- backend selection,
- policy risk classification.

This is here to support future agents and future iOS UI work with deterministic tests before the runtime bridge exists.

## Validation

Current package tests pass with:

```bash
swift test
```

## Near-term next steps

1. Add a minimal iOS host app target.
2. Implement capability detection on real devices.
3. Add container/import persistence.
4. Build the first embedded runtime spike.
5. Prove one launchable sample path.
