# Libre40

Libre40 is a ReXGlue-based native PC recompilation workspace for Army of Two: The 40th Day on Xbox 360.

Compatibility note: you must provide your own legally obtained disc/ISO extraction. This repository does not include game assets, retail binaries, generated code from a retail binary, keys, patches, or downloads.

## Quick Start

Clone or place the official ReXGlue SDK under ignored local tools:

```powershell
git clone --recursive https://github.com/rexglue/rexglue-sdk.git tools\rexglue-sdk
```

Build and install the official SDK:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-rexglue-official.ps1
```

Extract your legally obtained ISO into `game\`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\extract-game.ps1
```

Build this project:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-l40.ps1 -Regenerate
```

Run the game manually after a successful build:

```powershell
powershell -ExecutionPolicy Bypass -File .\rungame.ps1 -StopExisting
```

## Current Status

Public scaffold, legal hygiene policy, official ReXGlue build helper, extraction helper, manifest placeholder, and host build target are in place. Extraction, ReXGlue codegen, and first boot are still pending local execution.

## Repo Map

- `config/l40_manifest.toml` - ReXGlue project manifest.
- `rungame.ps1` - manual game launcher after a successful build.
- `scripts/` - extraction, build, and audit helpers.
- `src/` - minimal ReXGlue app customization.
- `config/` - tracked ReXGlue function hints.
- `docs/` - setup, legal policy, development notes, and status.

## ReXGlue

This repo defaults to the official `rexglue/rexglue-sdk` repository at `tools\rexglue-sdk`. Do not use ReXGlue forks for Libre40 unless an SDK-level issue is proven and explicitly reviewed.

## Legal / Repo Hygiene

Keep this repo free of game assets and generated game-derived code. See `docs/legal.md`.
