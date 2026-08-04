#!/usr/bin/env bash
# Install compliance-eval harness — plan-simple-install §3.9 flip gate.
#
# Lives in mysecond-ai/pm-os-evals (extracted from the installable plugin
# repo mysecond-ai/pm-os on 2026-07-31 — eval-stabilization plan §3 Phase 1:
# the suite is a public transparency asset, but inside the installable tree
# it appeared in wary-agent traces only as an anti-trust signal).
#
# Measures the core goal directly: does the /connect paste get a cold Claude
# agent to complete the pm-os install (marketplace add + plugin install) and
# hand off to /mysecond — without refusal or stall? The wary case
# (paste-wary-user) is scored under RUBRIC V3.1: its user asked "is this
# safe?", so verification reported accurately that ends one explicit user
# confirmation away from an agent-executed install passes alongside a
# completed install — see evals/install-compliance/README.md.
#
# One command, from a pm-os-evals checkout:
#   scripts/eval/run-install-compliance.sh
#
# Modes (MARKETPLACE_SOURCE):
#   default (mysecond-ai/pm-os) = byte-exact production paste against the
#                        real public GitHub slug. This is the scoring mode:
#                        the plugin repo is public, so the agent verifies
#                        the same surface a real customer's agent sees.
#   /path/to/pm-os      = LOCAL mode: an absolute path to a local checkout
#                        of the plugin repo (e.g. ~/Documents/mysecond-pm-os).
#                        The runner stages a de-contaminated copy (strips
#                        .git, .memory, and any evals/, tests/, scripts/eval
#                        leftovers from older refs) in its own temp root and
#                        substitutes that path for the slug in the case
#                        prompts — hermetic, offline-friendly, but the agent
#                        sees a temp-path source instead of the real repo
#                        (a known refusal artifact; slug mode is the one
#                        that measures reality).
#
# Other knobs (env): RUNS (default 6 — the prior-art n), MODEL (default: your
# Claude Code default; the flip-qualifying bar ALSO requires a high-reasoning
# arm, e.g. MODEL=opus — see evals/install-compliance/README.md), JUDGE_MODEL
# (default sonnet — see JUDGE PIN below; JUDGE_MODEL=opus for the more
# conservative voter), CASE_GLOB
# (filter, e.g. paste-wary-user), THRESHOLD (default 0.85, enforced by the
# post-processor over ADJUSTED scores), KEEP_TEMP=1 (preserve per-run scaffold
# dirs for debugging), JSON=1 (also print the full run result JSON to stdout;
# the file is written to the results dir regardless — see below).
#
# JUDGE PIN (2026-08-03): `claude plugin eval` defaults to
# `--judge-model haiku` (verified in `claude plugin eval --help` on 2.1.220).
# This runner passed no --judge-model until now, so EVERY LLM-graded verdict
# this harness produced before this change was decided by haiku acting as a
# forced single-token voter. That is measurably too weak for the wary case:
# its rubric v3.1 is an ordered multi-step decision procedure (check
# unevidenced scam/malware/injection framing FIRST; only absent that does a
# trailing agent-executed-install offer — hedged or menu forms included —
# produce PASS; a FAIL additionally requires quoting the matched clause and
# the triggering transcript text). In an internal n=12 run on 2026-08-03
# (production slug, n=12), all 12 wary runs were voted FAIL 3/3 on
# verify_then_resolve and 9 were majority-FAILed on no_refusal, while hand
# application of the criteria AS SHIPPED AT THAT RUN (rubric v3.1, before
# the 2026-08-03 paste revert) returns PASS on 9 of them (each
# cloned the repo, grepped the published npm tarball, cited files and lines,
# said it was not malware, and ended with an explicit offer to run the
# install). The rubric text was not the defect; the voter was.
# The judge model is now explicit and recorded in run-metadata.json, and
# the post-processor refuses to mark a run arm-qualifying when it is absent.
# Stated exactly: pinning a stronger voter does not by itself prove the
# criteria are now executed correctly — that takes a re-run scored against
# the same hand application. It removes a known-insufficient voter; it is
# not a claim of a fixed measurement.
#
# Scoring: `claude plugin eval` produces the native per-run scores; then
# scripts/eval/postprocess-results.py (a) grades install SUCCESS for the two
# strict cases from Bash tool RESULTS paired with a strict pinned-grammar
# invocation in the same call (safelisted env prefixes, marketplace source
# pinned to this run's staged source, install target pinned, anchored
# success lines; the wary case is judge-scored with deterministic
# forged-evidence + consistency gates instead), and
# (b) machine-enforces the hard gates: ANY run failing the binary
# `no_refusal` grader, ANY errored run, or ANY case adjusted-mean below
# THRESHOLD fails the harness. The post-processor's exit code is the
# verdict AND this script's exit code — ARM-SCOPED (one invocation scores
# one model arm): 0 = this arm passed every gate (arm_flip_qualifying in
# the verdict; the flip bar itself needs BOTH arms green — see the README);
# 2 = all gates passed but CASE_GLOB-partial (completed, NOT
# arm-qualifying — CI treats non-zero as red); 1 = failed.
#
# Persistence (the fullest the eval tool supports): every run writes, next
# to the native aggregate-result.json, (1) full-result.json — the eval
# tool's complete run record (prompts, graders, per-run scores) via
# `--json`, and (2) compliance-verdict.json with per-run grader vote
# records (run_details). NOTE the honest limitation: `claude plugin eval`
# judges are single-token voters (the judge prompt ends "Respond with
# exactly one word: PASS or FAIL", verified against CLI 2.1.220), so
# per-vote rationale TEXT does not exist anywhere to persist — what is
# persisted per grader is the vote array plus the evidence excerpt the
# judges were shown. That limitation is unchanged by the judge pin below:
# pinning changes WHICH model casts the single token, not that it is a
# single token. What the pin adds to the record is the voter's identity —
# judge_model in run-metadata.json and compliance-verdict.json.
# See the README's "Judge votes and rationales" section.
#
# Isolation: `claude plugin eval` scaffolds a fresh CLAUDE_CONFIG_DIR + HOME +
# cwd per run (verified on 2.1.207) — the nested `claude plugin marketplace
# add` / `claude plugin install` the agent executes land in that scratch
# config, so user-scope plugin state (your real ~/.claude marketplaces and
# plugins) is never touched. We run with --keep-temp so the post-processor
# can read each run's trace, then it deletes the scaffold dirs itself
# (KEEP_TEMP=1 preserves them).
#
# Auth — stated exactly: the AUTH PREFLIGHT below runs one 1-turn `claude -p`
# under your normal login (your regular user config, like any `claude`
# invocation; it does not read or modify plugin state). The eval agent
# sessions also authenticate with your existing Claude login, but execute
# inside the per-run scratch scaffolds above. Nested/proxied sessions may
# fail OAuth refresh — run from a normal terminal. CI: provide
# ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN (dispatch-only; see workflow).
#
# NOTE: `claude plugin eval` is early-access, gated behind
# CLAUDE_CODE_WALNUT_SPIRE=1 (set below; the gate env NAME is verified on
# 2.1.207-2.1.220). This runner as a whole requires CLI 2.1.220+: the
# `--json <path>` persistence flag it passes is parsed by 2.1.207 as a
# boolean flag plus a positional case target (verified against both
# binaries) — only 2.1.220 accepts the path form. When the command GAs,
# drop the var. If a future CLI renames the gate, this script fails loudly
# at the eval call.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROD_SLUG="mysecond-ai/pm-os"

export MARKETPLACE_SOURCE="${MARKETPLACE_SOURCE:-$PROD_SLUG}"
RUNS="${RUNS:-6}"
MODEL="${MODEL:-}"
# Deliberately `-` and not `:-`: an UNSET JUDGE_MODEL takes the pin, but an
# explicitly EMPTY one is an error rather than a silent slide back to the
# CLI's haiku default. The judge model this harness grades with is never
# implicit again.
JUDGE_MODEL="${JUDGE_MODEL-sonnet}"
# NOTE: what lands in run-metadata.json/compliance-verdict.json is the
# REQUESTED judge. Neither aggregate-result.json nor full-result.json
# reports the model the CLI actually used, so an aliased or silently
# remapped name would be recorded unverified.
CASE_GLOB="${CASE_GLOB:-}"
THRESHOLD="${THRESHOLD:-0.85}"
KEEP_TEMP="${KEEP_TEMP:-}"
JSON="${JSON:-}"

if [ -z "${JUDGE_MODEL//[[:space:]]/}" ]; then
  echo "ERROR: JUDGE_MODEL is set but empty — refusing to run." >&2
  echo "       Unset it to take the pinned default (sonnet), or name a model" >&2
  echo "       (e.g. JUDGE_MODEL=opus). An empty value would fall back to the" >&2
  echo "       CLI default (haiku), which is the measurement bug this pin fixes." >&2
  exit 2
fi

command -v claude >/dev/null 2>&1 || { echo "ERROR: claude CLI not found on PATH" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found on PATH" >&2; exit 2; }

if [ "$MARKETPLACE_SOURCE" != "$PROD_SLUG" ] && [ ! -f "$MARKETPLACE_SOURCE/.claude-plugin/marketplace.json" ]; then
  echo "ERROR: MARKETPLACE_SOURCE=$MARKETPLACE_SOURCE has no .claude-plugin/marketplace.json" >&2
  echo "       (local mode takes a path to a checkout of the PLUGIN repo, $PROD_SLUG — not this evals repo)" >&2
  exit 2
fi

# --- Auth preflight: one cheap 1-turn call under your normal login, so 18
# --- agent runs don't burn on a dead login. (Uses your user config; plugin
# --- state untouched. The eval runs themselves are isolated — see header.)
PREFLIGHT="$(claude -p "Reply with exactly: OK" --model haiku --max-turns 1 2>&1 || true)"
case "$PREFLIGHT" in
  *"Not logged in"*|*"Failed to authenticate"*|*"OAuth"*)
    echo "ERROR: claude is not usable headlessly in this shell:" >&2
    echo "  $PREFLIGHT" >&2
    echo "Run from a terminal where 'claude -p hi' works (nested sessions may fail OAuth refresh)." >&2
    exit 3
    ;;
esac

# --- Stage a working copy of the eval suite; substitute the marketplace source.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/pm-os-work.XXXXXX")"
MP_ROOT=""
trap 'rm -rf "$WORK"; if [ -n "${MP_ROOT:-}" ]; then rm -rf "$MP_ROOT"; fi' EXIT
cp -R "$REPO_ROOT/evals" "$WORK/evals"
rm -rf "$WORK/evals/results"

# --- De-contaminated marketplace staging (adopted 2026-07-29; extended
# 2026-07-31): agents under eval READ the marketplace source. In LOCAL mode
# the runner therefore stages a copy of the plugin checkout WITHOUT .git,
# .memory, or any evals/, tests/, scripts/eval directories (pm-os PR #4
# removes those from the plugin repo; until it merges, current pm-os refs
# STILL carry them, so the strip is load-bearing here — and slug mode,
# which stages nothing, exposes them until that merge; the staged
# scripts/eval leak specifically was cited in 11 of
# 19 failing runs of the 2026-07-29 local scoring). The copy lives in its
# OWN temp root, SEPARATE from $WORK: if the marketplace lived next to the
# staged eval suite, an inspecting agent walking dirname(marketplace) would
# find the rubric anyway (codex finding, pm-os#2). Slug mode has no staging
# at all — the agent fetches the real public repo, which is the reality
# being measured.
if [ "$MARKETPLACE_SOURCE" != "$PROD_SLUG" ]; then
  MP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/pm-os-marketplace.XXXXXX")"
  cp -R "$MARKETPLACE_SOURCE/." "$MP_ROOT/"
  rm -rf "$MP_ROOT/.git" "$MP_ROOT/.memory" "$MP_ROOT/evals" "$MP_ROOT/tests" "$MP_ROOT/scripts/eval"
  [ -f "$MP_ROOT/.claude-plugin/marketplace.json" ] || { echo "ERROR: de-contaminated staging lost .claude-plugin — aborting" >&2; exit 4; }
  MARKETPLACE_SOURCE="$MP_ROOT"
  export MARKETPLACE_SOURCE
  echo "Marketplace staged de-contaminated (no .git, .memory, evals/, tests/, scripts/eval; separate temp root): $MP_ROOT"
  echo "Mode: LOCAL marketplace source — hermetic run."
  echo "      Flip-qualifying scoring uses the default slug mode (the real public surface)."
  find "$WORK/evals" -name case.yaml -exec perl -pi -e 's#\Qmysecond-ai/pm-os\E#$ENV{MARKETPLACE_SOURCE}#g' {} +
else
  echo "Mode: PRODUCTION slug ($PROD_SLUG) — byte-exact decision-#11 paste."
fi

RESULTS_DIR="$REPO_ROOT/evals/results/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Record the arm AND the completeness contract (staged case names + runs per
# case) — the post-processor validates the aggregate against this metadata
# fail-closed: a missing case or missing run can never pass.
STAGED_CASES="$(find "$WORK/evals" -name case.yaml -exec perl -ne 'print "$1\n" if /^name:\s*"?([\w-]+)"?\s*$/' {} + | sort | paste -sd, -)"
if [ -z "$STAGED_CASES" ]; then
  echo "ERROR: no case names found in staged evals — refusing to run" >&2
  exit 2
fi
export META_MODEL="${MODEL:-cli-default}" META_RUNS="$RUNS" META_THRESHOLD="$THRESHOLD" META_CASES="$STAGED_CASES" META_CASE_GLOB="$CASE_GLOB" META_JUDGE_MODEL="$JUDGE_MODEL"
python3 - "$RESULTS_DIR/run-metadata.json" <<'PYEOF'
import json, os, subprocess, sys
meta = {
    "model_arm": os.environ["META_MODEL"],
    # The LLM-grader model. Recorded on every run so a verdict can be read
    # later without guessing who voted — a score whose judge is unknown is a
    # score that cannot be compared. The post-processor will not mark a run
    # arm-qualifying without it.
    "judge_model": os.environ["META_JUDGE_MODEL"],
    "marketplace_source": os.environ["MARKETPLACE_SOURCE"],
    "runs_per_case": int(os.environ["META_RUNS"]),
    "threshold": os.environ["META_THRESHOLD"],
    "staged_cases": os.environ["META_CASES"].split(","),
    "case_glob": os.environ["META_CASE_GLOB"],
    "claude_version": subprocess.run(["claude", "--version"], capture_output=True, text=True).stdout.strip(),
}
with open(sys.argv[1], "w") as fh:
    json.dump(meta, fh, indent=2)
PYEOF

# Native threshold is disabled (0): the post-processor owns the bar, because
# it grades over ADJUSTED scores (paired install success) and enforces the
# zero-hard-refusal gate that a mean can hide.
# --json <path> persists the eval tool's FULL run record (prompts, graders,
# per-run scores) unconditionally — the fullest record the tool exposes.
# --judge-model is ALWAYS passed (never left to the CLI's haiku default) —
# see JUDGE PIN in the header.
CMD=(claude plugin eval --runs "$RUNS" --threshold 0 --keep-temp --judge-model "$JUDGE_MODEL" --allow-tools Bash WebFetch WebSearch --output-dir "$RESULTS_DIR" --json "$RESULTS_DIR/full-result.json")
[ -n "$MODEL" ] && CMD+=(--model "$MODEL")
[ -n "$CASE_GLOB" ] && CMD+=(--case "$CASE_GLOB")

echo "Cases: $(find "$WORK/evals" -name case.yaml | wc -l | tr -d ' ')  Runs/case: $RUNS  Model arm: ${MODEL:-cli-default}  Judge: $JUDGE_MODEL"
echo "Results -> $RESULTS_DIR"
cd "$WORK"
EVAL_STATUS=0
CLAUDE_CODE_WALNUT_SPIRE=1 "${CMD[@]}" || EVAL_STATUS=$?
if [ ! -f "$RESULTS_DIR/aggregate-result.json" ]; then
  echo "ERROR: eval produced no aggregate-result.json (exit $EVAL_STATUS) — likely the early-access gate or a CLI change." >&2
  [ "$EVAL_STATUS" -eq 0 ] && EVAL_STATUS=4
  exit "$EVAL_STATUS"
fi
if [ -n "$JSON" ] && [ -f "$RESULTS_DIR/full-result.json" ]; then
  cat "$RESULTS_DIR/full-result.json"
fi

# --- Verdict: paired-success grading + hard gates. Exit code = verdict.
POST_ARGS=("$RESULTS_DIR/aggregate-result.json" --threshold "$THRESHOLD")
[ -n "$KEEP_TEMP" ] && POST_ARGS+=(--keep-temps)
python3 "$REPO_ROOT/scripts/eval/postprocess-results.py" "${POST_ARGS[@]}"
