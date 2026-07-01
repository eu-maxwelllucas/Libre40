# Building

Libre40 builds the `l40` host with **CMake + Ninja + Clang**, driven by native CMake
presets and a few small Python helper scripts (no PowerShell). Run the CMake commands
from an **"x64 Native Tools Command Prompt for VS 2022"** with `C:\Program Files\LLVM\bin`
on `PATH`. See [dependencies.md](dependencies.md) for prerequisites.

## Expected layout

```text
tools/rexglue-sdk/                            official ReXGlue SDK (git submodule, e8ce24f)
tools/rexglue-sdk/out/install/win-amd64/...   built + installed SDK (Ninja)
game/default.xex                              your legal extraction (git-ignored)
```

`iso/`, `game/`, `generated/`, and `build/` are git-ignored.

## Build steps

```
:: 1. Extract your game (ISO under iso/ -> game/)
python scripts\extract_iso.py

:: 2. Build the ReXGlue SDK once (Ninja, -mssse3, Tracy off)
python scripts\repair_sdk_symlinks.py
cmake --preset win-amd64 -S tools\rexglue-sdk -DCMAKE_C_FLAGS=-mssse3 -DCMAKE_CXX_FLAGS=-mssse3 -DREXGLUE_ENABLE_TRACY=OFF
cmake --build tools\rexglue-sdk\out\build\win-amd64 --config Release --target install

:: 3. Generate recompiled code (ReXGlue codegen + Libre40 workarounds)
python scripts\codegen.py

:: 4. Configure + build the host (note the -j 4 memory cap; see ninja-build.md)
cmake --preset release
cmake --build build\l40-ninja-release --target l40 -j 4

:: 5. Run
build\l40-ninja-release\l40.exe --game_data_root=game
```

After editing `config\l40_rexglue_overrides.toml` or `src/`, re-run step 3 (codegen) then
step 4 (build). Only the SDK step (2) is one-time.

## Build scripts

All build tooling is Python (standard library only) under `scripts/`:

| Script | What it does |
|---|---|
| `extract_iso.py` | Parse your Xbox 360 disc ISO (XDVDFS) and extract it into `game/`. Auto-detects the first `*.iso` under `iso/`, or takes an explicit path. Verifies `game/default.xex`. See [extraction.md](extraction.md). |
| `repair_sdk_symlinks.py` | Materialize the SDK's `libmspack` symlinks that Git checks out as text stubs on Windows (otherwise the SDK's cabextract build fails). Idempotent; run once before building the SDK. |
| `codegen.py` | Run ReXGlue codegen against `config/l40_manifest.toml` (writes `generated/default/`), then apply the Libre40 source workarounds. Run after extracting the game and building the SDK, before `cmake --preset release`. |
| `apply_workarounds.py` | Apply the patches in `l40_workarounds.json` to freshly generated code. Called automatically by `codegen.py`; idempotent (skips if already applied). Currently guards the splash shader-backend dereference in `generated/default/l40_recomp.81.cpp`. |
| `l40_workarounds.json` | The exact anchor/replacement patch text used by `apply_workarounds.py` (data, not a script). |

There are no PowerShell build scripts; the previous `build-l40.ps1` /
`build-rexglue-official.ps1` / `rungame.ps1` wrappers were replaced by the native CMake
commands and Python helpers above.

## Parallelism / memory

The recompiled `generated/default/l40_recomp.*.cpp` translation units are memory-heavy
(each includes the multi-MB `l40_init.h` at `-O3`), so an unbounded Ninja job count can
exhaust RAM and thrash Clang. Keep the `-j 4` cap on the `l40` build. The `release` build
preset also sets `jobs: 4`, so `cmake --build --preset release --target l40` is capped too.
See [ninja-build.md](ninja-build.md) for the full explanation and troubleshooting.

## Verify

A successful build ends with `[175/175] Linking CXX executable l40.exe` and produces
`build\l40-ninja-release\l40.exe` (~120 MB).
