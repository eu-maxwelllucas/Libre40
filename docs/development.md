# Development Notes

## Workflow

1. Change `config/l40_rexglue_overrides.toml` or project source.
2. Regenerate and rebuild:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-l40.ps1 -Regenerate
```

3. Run locally:

```powershell
powershell -ExecutionPolicy Bypass -File .\rungame.ps1 -StopExisting
```

## Compatibility Policy

Prefer official ReXGlue behavior. Add project code only for observed Libre40 needs, and keep SDK changes out of the tracked project unless an upstream SDK issue is proven and reviewed.

If logs report invalid or unregistered generated functions, add only the observed guest address to `config/l40_rexglue_overrides.toml`, regenerate, rebuild, and retest.

Generated code under `generated/` is disposable and should always be reproducible from the user's local legal extraction.

## Generated Workarounds

`scripts/build-l40.ps1 -Regenerate` applies `scripts/apply-l40-generated-workarounds.ps1` after official ReXGlue codegen. The current workaround guards the two splash shader factory dereferences in `generated/default/l40_recomp.81.cpp`; crash dumps showed the factory returning success while the output object slot held `0x00000001`.

Use `-SkipGeneratedWorkarounds` only for upstream ReXGlue comparison runs.
