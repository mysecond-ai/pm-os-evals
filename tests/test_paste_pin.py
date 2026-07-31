#!/usr/bin/env python3
"""Paste-pin check: every eval case embeds the canonical production paste.

The /connect page, the app-side constant (connect-paste-message.ts in
mysecond-app), and these eval cases must all carry the same decision-#11
paste bytes — eval fidelity is the whole point (decision #10's holdout
objection was caused by eval-artifact placeholders). The app side derives
from its own single constant; THIS repo pins its side of the contract here:
each case.yaml's prompt must embed the canonical paste held in exactly one
file, evals/install-compliance/paste.canonical.txt.

Comparison is whitespace-normalized (runs of whitespace collapse to one
space) because the case files legitimately re-wrap the paste with YAML
block scalars (`>-` folds newlines to spaces; `|-` keeps them). Any WORD
change — reordering, added/dropped sentences, slug edits — fails.

No YAML library: the prompt block scalar is extracted with plain
indentation rules so this check runs on a bare python3 (same constraint as
tests/test_postprocess.py).

Run: python3 tests/test_paste_pin.py   (exit 0 = every case pins the paste)
"""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SUITE = REPO / "evals" / "install-compliance"
CANONICAL = SUITE / "paste.canonical.txt"


def norm(text):
    return re.sub(r"\s+", " ", text).strip()


def extract_prompt(case_path):
    """Return the raw text of the `prompt:` block scalar in a case.yaml.
    Supports `prompt: >-` / `prompt: |-` style block scalars only — which is
    exactly what the committed cases use; anything else fails loudly."""
    lines = case_path.read_text(encoding="utf-8").splitlines()
    for idx, line in enumerate(lines):
        m = re.match(r"^(\s*)prompt:\s*[>|][+-]?\s*$", line)
        if m is None:
            continue
        key_indent = len(m.group(1))
        block = []
        for follower in lines[idx + 1:]:
            if not follower.strip():
                block.append("")
                continue
            indent = len(follower) - len(follower.lstrip())
            if indent <= key_indent:
                break
            block.append(follower.strip())
        if not any(block):
            raise SystemExit(f"{case_path}: prompt block scalar is empty")
        return "\n".join(block)
    raise SystemExit(f"{case_path}: no `prompt: >-`/`prompt: |-` block found")


def main():
    canonical_raw = CANONICAL.read_text(encoding="utf-8")
    canonical = norm(canonical_raw)
    problems = []
    if len(canonical) < 100 or "mysecond-ai/pm-os" not in canonical:
        problems.append(
            f"{CANONICAL}: canonical paste looks degenerate "
            f"({len(canonical)} normalized chars) — refusing to pin against it")
    cases = sorted(SUITE.glob("*/case.yaml"))
    if len(cases) < 3:
        problems.append(f"expected at least 3 case files, found {len(cases)}")
    for case_path in cases:
        prompt = norm(extract_prompt(case_path))
        rel = case_path.relative_to(REPO)
        if canonical in prompt:
            print(f"ok    {rel} embeds the canonical paste")
        else:
            problems.append(
                f"{rel}: prompt does not embed the canonical paste "
                "(evals/install-compliance/paste.canonical.txt) — the case "
                "and the constant must change together")
    print()
    if problems:
        for p in problems:
            print(f"FAIL  {p}")
        return 1
    print(f"paste pin holds across {len(cases)} case(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
