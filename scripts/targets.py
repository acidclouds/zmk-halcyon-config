#!/usr/bin/env python3
"""Print build targets from a build.yaml, one per line:
artifact-name TAB board TAB shield TAB snippet TAB cmake-args
Usage: targets.py build.yaml"""
import sys

import yaml


def main(path: str) -> None:
    with open(path) as f:
        doc = yaml.safe_load(f) or {}
    for t in doc.get("include", []):
        shield = t.get("shield", "") or ""
        board = t["board"]
        # A target can have no shield. Then the board name gives the fallback name.
        name = t.get("artifact-name") or (
            shield.split()[0] if shield.split() else board.replace("/", "_")
        )
        print("\t".join([
            name,
            board,
            shield,
            t.get("snippet", "") or "",
            t.get("cmake-args", "") or "",
        ]))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: targets.py build.yaml", file=sys.stderr)
        sys.exit(2)
    main(sys.argv[1])
