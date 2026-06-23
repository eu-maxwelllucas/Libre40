# Dependencies

## ReXGlue SDK

Use the official ReXGlue SDK repository. Do not use local forks for Libre40 unless an SDK-level issue is proven and explicitly reviewed.

Default local layout:

```text
Libre40/
  tools/rexglue-sdk/
```

Clone:

```powershell
git clone --recursive https://github.com/rexglue/rexglue-sdk.git tools\rexglue-sdk
```

Build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-rexglue-official.ps1
```

On Windows, the build helper materializes libmspack symlink placeholders inside the ignored SDK checkout when Git checked them out as text files. It also defaults Clang builds to `-mssse3`, matching the current official SDK build needs observed in the Army project.

The project build script defaults to:

```text
tools\rexglue-sdk\out\install\win-amd64-nmake
```

## Extraction Tools

`scripts\extract-game.ps1` defaults to this repo's local 360tools snapshot:

```text
tools\360tools
```

Pass `-ToolsRoot` to use another local checkout.

## Game Data

This project does not provide game files. Put your own legal extraction in ignored `game/`.
