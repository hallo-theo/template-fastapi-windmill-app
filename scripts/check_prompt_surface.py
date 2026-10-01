#!/usr/bin/env python3
"""Prompt-surface drift check.

The agent prompts in this repo's workflows are the only place org contracts
reach the model: a contract (docs/PRODUCT.md, docs/DESIGN.md, the roadmap
rules) can silently stop being mentioned while every other check stays green
— the model then simply doesn't know. (Org pattern adapted from
prosa-ai-chat's check:agent.)

sdlc/prompt-contracts.json pins two things per prompt-bearing file:
- a content hash, so ANY change to a prompt fails CI until the hash is
  consciously updated in the same PR — the check asks "did the prompt move
  with the capability?"; theo-pr-reviewer answers the semantic half;
- marker regexes that must always match — the org contracts the prompt
  must keep carrying.

Usage: scripts/check_prompt_surface.py [--update]
  --update   re-pin the hashes to the current file contents (markers are
             still enforced — an update cannot bless a dropped contract)
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

MANIFEST = Path("sdlc/prompt-contracts.json")


def digest(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()[:16]


def main() -> int:
    update = "--update" in sys.argv[1:]
    if not MANIFEST.exists():
        print(f"::error::{MANIFEST} not found — run from the repo root")
        return 1
    manifest = json.loads(MANIFEST.read_text())
    failures: list[str] = []
    for entry in manifest["files"]:
        path = Path(entry["path"])
        if not path.exists():
            failures.append(
                f"{entry['path']}: listed in {MANIFEST} but missing from the repo — "
                f"remove the entry if the file is gone on purpose"
            )
            continue
        text = path.read_text(encoding="utf-8")
        d = digest(text)
        if update:
            entry["sha256_16"] = d
        elif d != entry["sha256_16"]:
            failures.append(
                f"{entry['path']}: prompt surface changed (now {d}, pinned {entry['sha256_16']}). "
                f"Re-read the prompt against its contracts, then run "
                f"scripts/check_prompt_surface.py --update and commit the manifest IN THIS PR."
            )
        for marker in entry["must_mention"]:
            if not re.search(marker["pattern"], text, re.S):
                failures.append(
                    f"{entry['path']}: no longer mentions the org contract "
                    f"'{marker['contract']}' (pattern /{marker['pattern']}/). If dropping it is "
                    f"intended, remove the marker from {MANIFEST} in the same PR and say why "
                    f"in the PR body."
                )
    if update:
        MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
        print(f"pinned hashes updated in {MANIFEST}")
    for f in failures:
        print(f"::error::{f}")
    if not failures and not update:
        print(
            f"prompt surface matches {MANIFEST}: "
            f"{len(manifest['files'])} files, every contract mentioned"
        )
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
