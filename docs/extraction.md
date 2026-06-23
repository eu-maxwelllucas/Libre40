# Extraction

Use only a legally obtained compatible game copy.

The local ISO currently expected by the helper is:

```text
iso/Army of Two - The 40th Day (USA, Australia) (En,Fr,De,Es,It).iso
```

Extract with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\extract-game.ps1
```

Capture XEX header and import notes into ignored `private/`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\extract-game.ps1 -Analyze
```

If the ISO extractor reports that the disc image may be encrypted, use a legal local extractor outside this public tree, then place the extracted files in `game/` so `game/default.xex` exists.
