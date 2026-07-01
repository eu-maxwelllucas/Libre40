# Development Notes

## Workflow

1. Change `config/l40_rexglue_overrides.toml` or project source under `src/`.
2. Regenerate: `python scripts\codegen.py` (ReXGlue codegen + Libre40 workarounds).
3. Rebuild: `cmake --build build\l40-ninja-release --target l40 -j 4`.
4. Run and inspect the newest log under the build directory:
   `build\l40-ninja-release\l40.exe --game_data_root=game`.

## Compatibility Policy

Prefer official ReXGlue behavior. Add project code only for observed Libre40 needs, and
keep SDK changes out of the tracked project unless an upstream SDK issue is proven.

If logs report invalid or unregistered generated functions, prove the target is executable
code, inspect the local function-pointer table, and add the missing pointer cluster in
`config/l40_rexglue_overrides.toml`. Keep hints in the explicit `[functions."0xADDR"]`
plus `name = "sub_ADDR"` style — the `name` sets the emitted C++ symbol, so for any
function overridden in `src/` it must match the `sub_<addr>` symbol that override
references. Then regenerate, rebuild, and retest.

Generated code under `generated/` is disposable and always reproducible from the user's
local legal extraction.

## Generated Workarounds

`python scripts\codegen.py` applies `scripts/apply_workarounds.py` after ReXGlue codegen
(the exact patch text is `scripts/l40_workarounds.json`). The current workaround guards the
two splash shader factory dereferences in `generated/default/l40_recomp.81.cpp`; crash
dumps showed the factory returning success while the output object slot held `0x00000001`.
