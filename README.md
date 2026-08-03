# pm-os-evals — public install-compliance evals for the mySecond plugin

The eval harness that gates the [mySecond](https://mysecond.ai) simple-install
migration: **does the /connect paste get a cold Claude agent to complete the
[`pm-os`](https://github.com/mysecond-ai/pm-os) plugin install — marketplace
add + plugin install + `/mysecond` hand-off — without refusal or stall?**
(The wary-user case scores a different bar on purpose: accurate verification
with the install at most one confirmation away — see the rubric.)

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
| `tests/` | 26 CI-enforced checks: 22 fail-closed fixture scenarios + the tracked-file raw-byte scan + 3 paste-pin cases |

## Running

Requires the Claude Code CLI (`claude`) logged in, `python3`, `bash`.

```bash
scripts/eval/run-install-compliance.sh                 # default arm, production slug mode
MODEL=opus scripts/eval/run-install-compliance.sh      # high-reasoning arm
MODEL=sonnet scripts/eval/run-install-compliance.sh    # sonnet arm
JUDGE_MODEL=opus scripts/eval/run-install-compliance.sh # stronger LLM-grader voter (default: sonnet)
RUNS=12 CASE_GLOB=paste-exact \
  scripts/eval/run-install-compliance.sh               # bigger n on one case (exits 2: partial)
MARKETPLACE_SOURCE=/path/to/pm-os-checkout \
  scripts/eval/run-install-compliance.sh               # hermetic local mode (plumbing checks only)
```

Exit code contract (arm-scoped — one invocation scores one model arm):
`0` = this run passed every gate, `2` = all gates passed but the run was
case-filtered (partial), `1` = failed. `arm_flip_qualifying` in the verdict
is stricter than exit 0: it also requires production slug mode on a
registered arm (`cli-default` or `MODEL=opus`) and a recorded judge model —
a passing local-mode, other-arm, or unrecorded-judge run exits 0 but
records NOT arm-qualifying. The flip bar itself
needs BOTH registered arms green — see the suite README. Each run writes
`evals/results/<timestamp>/` with `aggregate-result.json` (native scores +
per-grader judge votes + evidence excerpts), `full-result.json` (the eval
tool's complete run record), `run-metadata.json` (the completeness
contract, including `judge_model`), and `compliance-verdict.json` (the
verdict, including the judge model and per-run grader vote records under
`run_details`).

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

**Which model votes.** `claude plugin eval` defaults to
`--judge-model haiku`. Since 2026-08-03 the runner pins the judge
explicitly — **`sonnet`** by default, overridable with the `JUDGE_MODEL`
env var (`JUDGE_MODEL=opus scripts/eval/run-install-compliance.sh`) — and
records it as `judge_model` in both `run-metadata.json` and
`compliance-verdict.json`. A verdict with no recorded judge model is never
marked arm-qualifying. The single-token limitation above is unchanged by
this: pinning changes *which model* casts the one token, not that it is
one token.

**Scores recorded before that pin are not comparable to scores after it.**
Every LLM-graded verdict this harness produced before 2026-08-03 was
decided by haiku, because the runner passed no `--judge-model`. For the
two strict cases that is a caveat; for `paste-wary-user` it invalidates
the numbers. Its rubric v3.1 is an ordered multi-step decision procedure,
and haiku did not execute it: in the n=12 production-slug run of
2026-08-03, all 12 wary runs were voted FAIL 3/3 on `verify_then_resolve`
and 9 were majority-FAILed on `no_refusal`, while hand application of the
criteria as shipped at that run (rubric v3.1, before the 2026-08-03
paste revert) returns PASS on 9 of them — every one of those had
cloned the repo, inspected the published package, cited specific files and
lines, stated it was not malware, and ended with an explicit offer to run
the install. **Treat all pre-pin wary-case scores as void**, not as a
baseline to compare against. The rubric text was not the defect; the voter
was. Re-running under the pin is what produces a comparable number — the
pin removes a known-insufficient voter, it does not by itself demonstrate
that the criteria are now executed correctly.

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
