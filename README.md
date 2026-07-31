# pm-os-evals — public install-compliance evals for the mySecond plugin

The eval harness that gates the [mySecond](https://mysecond.ai) simple-install
migration: **does the /connect paste get a cold Claude agent to complete the
[`pm-os`](https://github.com/mysecond-ai/pm-os) plugin install — marketplace
add + plugin install + `/mysecond` hand-off — without refusal or stall?**

These evals are public on purpose. Every claim in the case prompts and
grading criteria is meant to be exactly true when read by the installing
agents themselves. They live in this repo — not inside the installable
plugin tree — because in analyzed traces, a rubric sitting inside the tree
an installing agent walks read as a persuasion surface, not a trust asset.
The plugin repo stays clean; the transparency stays here, one link away.

## Layout

| Path | What |
|---|---|
| `evals/install-compliance/` | The three cases + the suite README (start there) |
| `evals/install-compliance/paste.canonical.txt` | The single canonical production paste — CI pins every case against it |
| `scripts/eval/run-install-compliance.sh` | The one-command runner |
| `scripts/eval/postprocess-results.py` | Fail-closed verifier: completeness, pinned-grammar install credit, forged-evidence gates, hard gates, threshold |
| `tests/` | 22 CI-enforced checks: 21 fail-closed fixture scenarios + the tracked-file raw-byte scan, plus the paste-pin check |

## Running

Requires the Claude Code CLI (`claude`) logged in, `python3`, `bash`.

```bash
scripts/eval/run-install-compliance.sh                 # default arm, production slug mode
MODEL=opus scripts/eval/run-install-compliance.sh      # high-reasoning arm
MODEL=sonnet scripts/eval/run-install-compliance.sh    # sonnet arm
RUNS=12 CASE_GLOB=paste-exact \
  scripts/eval/run-install-compliance.sh               # bigger n on one case (exits 2: partial)
MARKETPLACE_SOURCE=/path/to/pm-os-checkout \
  scripts/eval/run-install-compliance.sh               # hermetic local mode (plumbing checks only)
```

Exit code contract: `0` = flip-qualifying pass, `2` = all gates passed but
the run was case-filtered (partial), `1` = failed. Each run writes
`evals/results/<timestamp>/` with `aggregate-result.json` (native scores +
per-grader judge votes + evidence excerpts), `full-result.json` (the eval
tool's complete run record), `run-metadata.json` (the completeness
contract), and `compliance-verdict.json` (the verdict, including per-run
grader vote records under `run_details`).

Isolation and auth are stated exactly in the runner header and the suite
README — eval runs execute in per-run scratch scaffolds and never touch
your real `~/.claude` plugin state.

## Judge rationales — the honest limitation

`claude plugin eval`'s LLM judges are single-token voters: each judge is
instructed to *"Respond with exactly one word: PASS or FAIL"* (verified
against Claude Code 2.1.220). Per-vote rationale text therefore does not
exist to persist. This harness persists the fullest record the mechanism
supports — every vote, the evidence excerpt the judges saw, the full run
record, per-run vote records in the verdict file, and kept traces on any
failing verdict — and the wary case's v3.1 criteria require judges to
ground a FAIL in a quoted clause + transcript text *in their reasoning*,
which shapes the vote but is not itself capturable. Details:
`evals/install-compliance/README.md`, "Judge votes and rationales".

## CI

- `ci.yml` (every push/PR, no credentials): post-processor fixture suite +
  tracked-file raw-byte scan + paste-pin check.
- `install-compliance-eval.yml` (manual dispatch only): the live harness;
  credentials exist on dispatch only and are never stored in this repo.

## Provenance

Extracted byte-exact from `mysecond-ai/pm-os@de79348` (eval-stabilization
plan §3 Phase 1, 2026-07-31), then rubric v3.1 + rationale persistence +
runner ergonomics landed on top. The plugin this measures:
[github.com/mysecond-ai/pm-os](https://github.com/mysecond-ai/pm-os).

Questions: support@mysecond.ai
