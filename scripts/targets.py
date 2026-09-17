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
        name = t.get("artifact-name") or t["shield"].split()[0]
        print("\t".join([
            name,
            t["board"],
            t["shield"],
            t.get("snippet", "") or "",
            t.get("cmake-args", "") or "",
        ]))


if __name__ == "__main__":
    main(sys.argv[1])
