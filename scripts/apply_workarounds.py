#!/usr/bin/env python3
"""Apply Libre40 source workarounds to freshly generated code.

ReXGlue codegen emits vanilla recompiled C++. Libre40 needs a few targeted edits
on top (splash shader-backend null guards) for a working build. This applies them
deterministically and idempotently right after codegen; the exact patch text
lives in ``l40_workarounds.json``.

Run automatically by scripts/codegen.py, or manually:
    python scripts/apply_workarounds.py
"""

import json
import os
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "l40_workarounds.json")


def apply_target(target):
    path = os.path.join(REPO_ROOT, target["file"].replace("/", os.sep))
    if not os.path.isfile(path):
        raise SystemExit(f"Generated file not found: {path} (run codegen first)")

    with open(path, "r", encoding="utf-8") as f:
        text = f.read().replace("\r\n", "\n")

    labels = target["labels"]
    present = [l for l in labels if l in text]
    missing = [l for l in labels if l not in text]
    if present:
        if not missing:
            print(f"already applied: {target['file']}")
            return
        raise SystemExit(f"partial workaround in {target['file']}; missing: {missing}")

    for seg in target["segments"]:
        needle = seg["needle"]
        idx = text.find(needle)
        if idx < 0:
            raise SystemExit(f"cannot apply '{seg['description']}' in {target['file']}: "
                             "anchor text not found (did codegen output change?)")
        text = text[:idx] + seg["replacement"] + text[idx + len(needle):]

    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    print(f"applied: {target['file']}")


def main():
    with open(DATA, "r", encoding="utf-8") as f:
        data = json.load(f)
    for target in data["targets"]:
        apply_target(target)


if __name__ == "__main__":
    main()
