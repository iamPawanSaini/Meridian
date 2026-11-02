#!/usr/bin/env bash
# Automated checks for T04a (coding standards and quality gates). Designed from the acceptance criteria
# in docs/TASKS.md, the approved plan docs/tasks/T04a/plan.md and the decisions in
# docs/tasks/T04a/decision-t04a-standards.md, NOT from the implementation. Failing now is expected.
#
# Usage:  docs/tests/T04a/run-checks.sh               agent-runnable cases (task close)
#         docs/tests/T04a/run-checks.sh --regression  invariant checks only (CI PR set, decision D-5)
#         docs/tests/T04a/run-checks.sh --owner       owner-run cases 36-47 (needs network; works in a
#                                                     throwaway copy of the tree, bootstraps pre-commit there)
# Exit status is non-zero if any executed check fails. A missing file makes every dependent check FAIL
# (no vacuous pass). SKIP only for optional tools (ruff, mypy, shellcheck, yamllint, markdownlint); the
# report lists them. BLOCKED lines are owner-run or deferred cases (T05, T08, T09, T21): they are not
# passes and do not change the exit status; the report must list each one.
#
# Tags (decision D-5): ckp = invariant (runs in both modes); cka = snapshot, true only at the close of
# T04a (git order, "no scaffolds yet", "verify" markers, process documents); skipped by --regression and
# the skipped count is printed. Retagging ckp -> cka needs a Change log entry in test-cases.md.
#
# Interface assumptions about the not-yet-written tooling. If the developer's interface differs, raise a
# clarification or defect; only the named adapter functions may then change (with a Change log row),
# never an expected result:
#   A-1 check_commit_msg.py  --msg-file F [--tasks-file T] | --range A..B [--tasks-file T]; default tasks
#       file docs/TASKS.md; reject = non-zero exit with a message.
#   A-2 check_branch_name.py [--branch B] [--tasks-file T]; else $GITHUB_HEAD_REF, else the current git
#       branch. exceptions_report.py [--out FILE] and check_assets.py take no root argument: they scan
#       the git working tree of the current directory (adapters ex_run, asset_run run them with cwd = a
#       throwaway repo holding docs/TASKS.md and docs/tests/defects.md).
#   A-3 QUALITY_STEPS = path of a file with lines NAME<TAB>MANIFEST<TAB>COMMAND that replaces the built-in
#       steps. MANIFEST '-' = always run; a path that is absent = SKIP; a present manifest and a command
#       that fails or is not found = FAIL (adapter qs_run).
#   A-4 coverage_gate.py --thresholds quality/coverage-thresholds.json COBERTURA.xml (adapter gate).
#   A-5 Cobertura fixture file names follow the D-1 path column (meridian_engine/scoring/...,
#       web/modules/custom/meridian_*/..., apps/web/lib/...).
# shellcheck disable=SC2329 # T04a: functions are invoked indirectly through ck, ckp and the adapters ("$@")
set -u
ROOT=$(git rev-parse --show-toplevel) || exit 2
cd "$ROOT" || exit 2
T=docs/tests/T04a
S=${T04A_SCRIPTS_DIR:-$ROOT/scripts}   # T04A_SCRIPTS_DIR: harness self-test against reference/ only

MODE=agent
case "${1:-}" in
  "") ;;
  --regression) MODE=reg ;;
  --owner) MODE=owner ;;
  *) echo "usage: $0 [--regression|--owner]" >&2; exit 2 ;;
esac
REG=0; [ "$MODE" = reg ] && REG=1

fail=0; excluded=0; ran=0; blocked=0; skipped=0
pass() { printf '  PASS  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=1; }
skip() { printf '  SKIP  %s\n' "$1"; skipped=$((skipped+1)); }
blk()  { printf '  BLOCKED  %s\n' "$1"; blocked=$((blocked+1)); }
# ckp DESC CMD...: invariant. cka DESC CMD...: snapshot (not run with --regression). The first lines of
# a failing check's output are shown so the cause is visible in the evidence.
ckp() { local d=$1 out rc; shift; ran=$((ran+1)); out=$("$@" 2>&1); rc=$?
  if [ $rc -eq 0 ]; then pass "$d"; else bad "$d"; printf '%s\n' "$out" | head -6 | sed 's/^/        /'; fi; }
cka() { local d=$1 out rc; shift
  if [ $REG -eq 1 ]; then excluded=$((excluded+1)); return 0; fi
  ran=$((ran+1)); out=$("$@" 2>&1); rc=$?
  if [ $rc -eq 0 ]; then pass "[at-close] $d"; else bad "[at-close] $d"; printf '%s\n' "$out" | head -6 | sed 's/^/        /'; fi; }

# ---------- generic helpers ----------
g()  { [ -s "$1" ] && grep -qiE -- "$2" "$1"; }                       # file non-empty and has pattern
gF() { [ -s "$1" ] && grep -qF -- "$2" "$1"; }                        # fixed string
hd() { [ -s "$1" ] && grep -qiE -- "^#+ .*($2)" "$1"; }               # heading matches
# shellcheck disable=SC2016 # T04a: awk program, deliberately single-quoted
AWKSEC='/^#+ /{match($0,/^#+/); l=RLENGTH; if(on&&l<=lv)on=0; if(!on && tolower($0) ~ tolower(re)){on=1;lv=l}} on'
sec()  { [ -s "$1" ] || return 1; awk -v re="$2" "$AWKSEC" "$1"; }
gsall(){ local f=$1 h=$2 s p; shift 2; s=$(sec "$f" "$h") || return 1; [ -n "$s" ] || return 1
  for p in "$@"; do grep -qiE -- "$p" <<<"$s" || { echo "missing in section '$h': $p"; return 1; }; done; }
allin(){ local f=$1 p; shift; [ -s "$f" ] || { echo "missing or empty: $f"; return 1; }
  for p in "$@"; do grep -qiE -- "$p" "$f" || { echo "missing in $f: $p"; return 1; }; done; }
exists_x() { [ -f "$1" ] && [ -x "$1" ]; }
put() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" >"$1"; }
# rejects CMD...: non-zero exit (not 127), a message, no Python traceback, no missing-script error.
rejects() { local out rc; out=$("$@" 2>&1); rc=$?
  [ "$rc" -ne 0 ] && [ "$rc" -ne 127 ] && [ -n "$out" ] && ! grep -qE "Traceback|can't open file" <<<"$out"; }
rejects_naming() { local pat=$1 out rc; shift; out=$("$@" 2>&1); rc=$?
  [ "$rc" -ne 0 ] && [ "$rc" -ne 127 ] && ! grep -qE "Traceback|can't open file" <<<"$out" && grep -qiE -- "$pat" <<<"$out"; }
accepts() { "$@" >/dev/null 2>&1; }
WORK=$(mktemp -d "${TMPDIR:-/tmp}/t04a.XXXXXX"); trap 'rm -rf "$WORK"' EXIT
mkrepo() {   # DIR: throwaway git repo with fixture TASKS.md and defects.md
  local d=$1; mkdir -p "$d"; git init -q -b main "$d" >/dev/null 2>&1 || return 1
  git -C "$d" config user.email t@example.invalid; git -C "$d" config user.name t
  git -C "$d" config commit.gpgsign false
  put "$d/docs/TASKS.md" "$(printf '## T04: x\n## T04a: y\n## T10: z\n## T32: w')"
  put "$d/docs/tests/defects.md" "$(printf '# Defects\n\n### DEF-001: fixture')"
  git -C "$d" add -A && git -C "$d" commit -qm "Initial commit"
}
FT=$WORK/TASKS.md; printf '## T04: x\n## T04a: y\n## T10: z\n## T32: w\n' >"$FT"

# =====================================================================================================
if [ "$MODE" != owner ]; then

SA=docs/standards/CODING_STANDARDS.md
RC=docs/standards/REVIEW_CHECKLIST.md
CT=quality/coverage-thresholds.json
PC=.pre-commit-config.yaml
MD_CFG=.markdownlint-cli2.yaml

echo "== TC-T04a-01 CODING_STANDARDS.md exists with a section per language (AC1)"
ckp "CODING_STANDARDS.md exists and is non-empty" test -s "$SA"
for h in 'PHP.*Drupal' 'Python' 'TypeScript.*Next|Next\.?js' 'SQL.*migration' 'Docker.*YAML|Docker' 'Shell' 'Markdown' 'OpenAPI' 'LLM.*prompt|prompt files'; do
  ckp "heading for '$h'" hd "$SA" "$h"
done
nomark() { [ -s "$1" ] && ! grep -nE '\b(TODO|TBD|FIXME|XXX)\b' "$1"; }
ckp "no TODO/TBD/FIXME markers in the standards" nomark "$SA"

echo "== TC-T04a-02 each language section names its tool and key rules (AC1, AC3)"
ckp "PHP: PHP_CodeSniffer, Drupal, DrupalPractice, PHPStan, phpstan-drupal, level 6" gsall "$SA" 'PHP.*Drupal' 'code ?sniffer|phpcs' 'DrupalPractice' 'phpstan' 'phpstan-drupal' 'level:? ?6'
ckp "PHP: no PHPStan baseline, ignores carry a reason" gsall "$SA" 'PHP.*Drupal' 'baseline' 'reportIgnoresWithoutComments|without comment'
ckp "Python: ruff, mypy, line length 100, py312 and py310 scope" gsall "$SA" '^#+ .*Python' 'ruff' 'mypy' '\b100\b' 'py312|3\.12' 'py310|3\.10'
ckp "Python: strict applied per invocation to scripts, .claude/hooks, meridian_engine" gsall "$SA" '^#+ .*Python' 'strict' 'scripts' '\.claude/hooks' 'meridian_engine'
ckp "TypeScript: ESLint, Prettier, tsc --noEmit, strict" gsall "$SA" 'TypeScript|Next' 'eslint' 'prettier' 'tsc --noEmit' 'strict'
ckp "SQL: Alembic migrations, reversible, parameterised queries" gsall "$SA" 'SQL' 'alembic' 'revers|downgrade' 'parameter'
ckp "Docker/YAML: hadolint, yamllint, pinned base image" gsall "$SA" 'Docker' 'hadolint' 'yamllint' 'pin'
ckp "Shell: shellcheck, set -euo pipefail" gsall "$SA" '^#+ .*Shell' 'shellcheck' 'set -euo pipefail'
ckp "Markdown: markdownlint, line length 100, tables exempt, TASKS.md exclusion cites T32" gsall "$SA" '^#+ .*Markdown' 'markdownlint' '\b100\b' 'table' 'T32'
ckp "OpenAPI: Spectral, openapi.yaml" gsall "$SA" 'OpenAPI' 'spectral' 'openapi\.yaml'
ckp "LLM prompts: versioned, untrusted data delimited (FR-07), no secrets" gsall "$SA" 'LLM.*prompt|prompt files' 'version' 'untrusted|inject' 'secret'

echo "== TC-T04a-03 cross-cutting rules (AC2)"
ckp "naming: section 0, meridian_engine, check-names.sh" gsall "$SA" 'naming' 'section 0|0 of' 'meridian_engine' 'check-names'
ckp "error handling section" gsall "$SA" 'error' 'exception'
ckp "structured logging: structured, JSON or key=value, no secrets in logs" gsall "$SA" 'logging' 'structured' 'json|key=value' 'secret'
ckp "no secrets in code: gitleaks, .env.example" gsall "$SA" 'secret' 'gitleaks' '\.env\.example'
ckp "dependency policy: lockfiles, pinned versions, audit before adding" gsall "$SA" 'dependenc' 'lock ?file' 'pin' 'audit'
ckp "comments and docstrings expectations" gsall "$SA" 'comment|docstring' 'why' 'docstring'
ckp "size guidance: function 50 lines, file 400 lines" gsall "$SA" 'size' '\b50\b' '\b400\b'

echo "== TC-T04a-04 tool table, exception rule, commit and branch rules, asset rules, scope (AC2 to AC4)"
tooltab() { local s r; s=$(sec "$SA" 'tool') || return 1
  grep -qiE '^\|.*version.*\|.*(source|url).*\|.*(date|checked)' <<<"$s" || { echo "no Version/Source/Date header"; return 1; }
  for r in ruff mypy 'code ?sniffer|phpcs' phpstan eslint prettier 'tsc|typescript' hadolint yamllint shellcheck markdownlint spectral; do
    grep -iE "^\|.*($r)" <<<"$s" | grep -qE '20[0-9]{2}-[0-9]{2}-[0-9]{2}' || { echo "no dated row: $r"; return 1; }
  done; }
ckp "tool table: Version, Source, Date checked, a dated row per tool" tooltab
ckp "exception rule: ticket regex literal" gF "$SA" '\b(T\d{2}a?|DEF-\d{3}): \S'
ckp "exception rule section: same line, counted in a report, DEF must exist" gsall "$SA" 'exception' 'same line' 'report' 'DEF-'
ckp "commit rules: Txx: prefix, 72 characters, Merge and Revert allowed, fixup! fails, PR range only" gsall "$SA" 'commit' '\b72\b' 'Merge' 'Revert' 'fixup!' 'range'
ckp "merge commits only for main, squash and rebase disabled" gsall "$SA" 'commit|branch' 'merge commit' 'squash'
ckp "branch rule: task/Txx-slug" gF "$SA" 'task/Txx-slug'
ckp "section 0b asset rules: self-hosted fonts and icons, no third-party hosts, colours only from tokens" gsall "$SA" 'asset|0b' 'self-host|same.origin' 'third.party' 'token'
ckp "scope table: docs/tests helpers ruff only, py310 for scripts, hooks and helpers" gsall "$SA" 'python|scope|tool' 'docs/tests' 'py310|3\.10'
webvitals() { [ -s "$SA" ] && grep -iE 'web-vitals' "$SA" | grep -E 'Apache|MIT' | grep -qE '[0-9]+\.[0-9]+'; }
ckp "web-vitals licence (Apache or MIT) and a pinned version recorded in the standards (OQ-T04-5)" webvitals

echo "== TC-T04a-05 coverage thresholds recorded in the standards (AC7)"
ckp "engine scoring and risk 90 (NFR-18), engine overall 85" gsall "$SA" 'coverage' 'scoring.*\b90|\b90.*scoring' 'risk.*\b90|\b90.*risk' '\b85\b' 'NFR-18'
ckp "Drupal custom modules 70, provisional, Kernel tests counted" gsall "$SA" 'coverage' '\b70\b' 'provisional' 'kernel'
ckp "Next.js lib and components 80; app routes covered by Playwright" gsall "$SA" 'coverage' '\b80\b' 'lib' 'components' 'playwright'
ckp "line coverage is the gate; branch reported not gated; floors only go up" gsall "$SA" 'coverage' 'line' 'branch.*(not gated|report)|(not gated|report).*branch' 'only go up|never lower|may not be lowered'

echo "== TC-T04a-06 quality/coverage-thresholds.json consistent with D-1 (AC7)"
json_ok() { python3 -I -c 'import json,sys; json.load(open(sys.argv[1]))' "$1"; }
ckp "thresholds JSON exists and is valid JSON" json_ok "$CT"
thr_ok() { python3 -I - "$CT" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
leaves = []                       # (context string, number)
def walk(o, ctx):
    if isinstance(o, dict):
        strs = " ".join(str(k) for k in o) + " " + " ".join(v for v in o.values() if isinstance(v, str))
        for k, v in o.items():
            if isinstance(v, (int, float)) and not isinstance(v, bool):
                leaves.append((ctx + " " + str(k) + " " + strs, float(v)))
        for k, v in o.items():
            walk(v, ctx + " " + str(k))
    elif isinstance(o, list):
        for v in o: walk(v, ctx)
walk(d, "")
def has(words, floor):
    return any((abs(v - floor) < 1e-9 or abs(v - floor / 100) < 1e-9) and all(w in c for w in words) for c, v in leaves)
need = [(["scoring"], 90), (["risk"], 90), (["meridian_engine"], 85), (["meridian_"], 70), (["lib"], 80), (["components"], 80)]
bad = [f"{w} {f}" for w, f in need if not has(w, f)]
if bad: print("missing floors:", bad)
sys.exit(1 if bad else 0)
PY
}
ckp "floors present: scoring 90, risk 90, engine 85, Drupal custom 70, web lib 80, web components 80" thr_ok
nolow() { python3 -I - "$CT" <<'PY'
import json, re, sys
d = json.load(open(sys.argv[1])); low = []
def walk(o, path):
    if isinstance(o, dict):
        for k, v in o.items():
            p = path + "/" + str(k)
            if isinstance(v, (int, float)) and not isinstance(v, bool) and re.search(r"scoring|risk", p) and "branch" not in p.lower():
                if 0 < v < 0.9 or 1 < v < 90: low.append(f"{p}={v}")
            else: walk(v, p)
    elif isinstance(o, list):
        for i, v in enumerate(o): walk(v, path + f"[{i}]")
walk(d, "")
print(low); sys.exit(1 if low else 0)
PY
}
ckp "no scoring or risk line floor below 90 percent (NFR-18 is fixed)" nolow

echo "== TC-T04a-07 REVIEW_CHECKLIST.md and the technical-architect reference (AC8)"
ckp "REVIEW_CHECKLIST.md exists" test -s "$RC"
ylist() { local n; n=$(grep -cE '^\s*(- \[ \]|[0-9]+\.|-) .*\?' "$RC"); echo "$n yes/no items"; [ "$n" -ge 30 ]; }
ckp "at least 30 yes/no (question) items" ylist
ckp "one block per standards section (PHP, Python, TypeScript, SQL, Docker, shell, Markdown, OpenAPI, prompts)" allin "$RC" 'PHP' 'Python' 'TypeScript' 'SQL' 'Docker' 'shell' 'Markdown' 'OpenAPI' 'prompt'
ckp "C1 to C7 each covered" allin "$RC" '\bC1\b' '\bC2\b' '\bC3\b' '\bC4\b' '\bC5\b' '\bC6\b' '\bC7\b'
ckp "simulation-only rule check (no order placement)" allin "$RC" 'simulation' 'order'
ckp "cross-cutting: naming, errors, logging, secrets, dependencies, size, exceptions cite a ticket" allin "$RC" 'naming' 'error' 'logging' 'secret' 'dependenc' 'size|50 lines' 'ticket'
ckp "technical-architect agent references REVIEW_CHECKLIST.md" gF .claude/agents/technical-architect.md 'REVIEW_CHECKLIST.md'

echo "== TC-T04a-08 root tool configs (AC3)"
ckp "ruff.toml: line-length 100, py312, per-file-target-version py310 for scripts, hooks, docs/tests" allin ruff.toml '^line-length *= *100' 'target-version *= *"py312"' 'per-file-target-version' 'py310' 'scripts' '\.claude/hooks' 'docs/tests'
ckp "mypy.ini exists" test -s mypy.ini
nomodstrict() { [ -s mypy.ini ] && ! awk '/^\[/{m=($0 ~ /^\[mypy-/)} m && /^ *strict *=/{f=1} END{exit f?0:1}' mypy.ini; }
ckp "mypy.ini does not rely on per-module strict (D-2, unverified in mypy docs)" nomodstrict
ckp ".yamllint.yaml: extends and line-length" allin .yamllint.yaml 'extends' 'line-length'
ckp ".markdownlint-cli2.yaml: MD013 line_length 100, tables/code_blocks/headings false" allin "$MD_CFG" 'MD013' 'line_length: *100' 'tables: *false' 'code_blocks: *false' 'headings: *false'
ckp ".shellcheckrc exists" test -s .shellcheckrc
tsstrict() { python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d["compilerOptions"]["strict"] is True else 1)' tsconfig.base.json; }
ckp "tsconfig.base.json valid JSON with strict true" tsstrict
ckp ".prettierrc.json valid JSON" json_ok .prettierrc.json

echo "== TC-T04a-09 component configs: PHP and ESLint (AC3)"
phpcs_ok() { python3 -I - apps/drupal/phpcs.xml.dist <<'PY'
import sys, xml.etree.ElementTree as ET
t = ET.parse(sys.argv[1]); s = open(sys.argv[1]).read()
assert t.getroot().tag == "ruleset"
for w in ("Drupal", "DrupalPractice", "web/modules/custom"): assert w in s, w
PY
}
ckp "phpcs.xml.dist: valid ruleset, Drupal, DrupalPractice, web/modules/custom" phpcs_ok
ckp "phpstan.neon.dist: level 6, comments on ignores, phpstan-drupal, custom modules" allin apps/drupal/phpstan.neon.dist '^ *level: *6' 'reportIgnoresWithoutComments: *true' 'phpstan-drupal|extension-installer' 'web/modules/custom'
nobase() { [ -s apps/drupal/phpstan.neon.dist ] && ! grep -qiE 'baseline|reportUnmatchedIgnoredErrors: *false' apps/drupal/phpstan.neon.dist; }
ckp "phpstan: no baseline file, stale ignores still reported" nobase
eslint_ok() { [ -s apps/web/eslint.config.mjs ] && node --check apps/web/eslint.config.mjs && grep -qi 'next' apps/web/eslint.config.mjs && grep -qi 'typescript-eslint' apps/web/eslint.config.mjs; }
ckp "eslint.config.mjs: parses with node, uses next and typescript-eslint" eslint_ok

echo "== TC-T04a-10 pre-commit hooks pinned (AC3, AC4)"
pins_ok() { python3 -I - "$PC" <<'PY'
import re, sys
lines = open(sys.argv[1]).read().splitlines()
repos = []                       # (url, rev)
for i, l in enumerate(lines):
    m = re.match(r"\s*- repo: (\S+)", l)
    if m:
        rev = None
        for l2 in lines[i + 1:i + 6]:
            r = re.match(r"\s*rev: *\"?([^\s\"#]+)", l2)
            if r: rev = r.group(1); break
            if re.match(r"\s*- repo:", l2): break
        repos.append((m.group(1), rev))
errs = []
for url, rev in repos:
    if url in ("local", "meta"): continue
    if not rev or not re.match(r"v?\d", rev): errs.append(f"unpinned: {url} rev={rev}")
for w in ["ruff", "mypy", "shellcheck", "yamllint", "hadolint", "markdownlint", "gitleaks", "pre-commit-hooks"]:
    if not any(w in u for u, _ in repos): errs.append(f"repo missing: {w}")
txt = "\n".join(lines)
if not re.search(r"@stoplight/spectral-cli@\d", txt): errs.append("spectral not pinned (@stoplight/spectral-cli@<version>)")
if not re.search(r"language: *node", txt): errs.append("spectral hook is not a node hook")
if not re.search(r"id: *ruff-format", txt) or not re.search(r"id: *ruff(-check)?\s*$", txt, re.M): errs.append("ruff lint and format hooks")
print("\n".join(errs)); sys.exit(1 if errs else 0)
PY
}
ckp "every non-local repo has a version rev; ruff (lint+format), mypy, shellcheck, yamllint, hadolint, markdownlint, Spectral (node, pinned)" pins_ok
ckp "default_install_hook_types includes pre-commit and commit-msg" allin "$PC" '^default_install_hook_types:.*pre-commit.*commit-msg|^default_install_hook_types:.*commit-msg.*pre-commit'
mypy_args() { python3 -I - "$PC" <<'PY'
import sys
t = open(sys.argv[1]).read(); i = t.find("mypy"); blk = t[i:i + 900]
for need in ("--strict", "3.10", "scripts", ".claude/hooks"):
    assert need in blk, need
PY
}
ckp "mypy hook: --strict, python 3.10, files scripts and .claude/hooks" mypy_args
verify_marks() { [ "$(grep -ciE '(^|[^-])verify' "$PC")" -ge 3 ]; }
cka "at least 3 'verify' markers (hook versions unconfirmed until the owner-run install, TC-36)" verify_marks

echo "== TC-T04a-11 commit-msg hook wiring is static-correct (AC4)"
cmwire() { python3 -I - "$PC" <<'PY'
import sys
L = open(sys.argv[1]).read().splitlines()
i = [n for n, l in enumerate(L) if "check_commit_msg" in l]
assert i, "no hook calls check_commit_msg.py"
assert "commit-msg" in "\n".join(L[max(0, i[0] - 12):i[0] + 12]), "hook is not at the commit-msg stage"
PY
}
ckp "a hook at stage commit-msg calls check_commit_msg.py" cmwire
ckp "bootstrap-dev.sh installs hooks (pre-commit install) and the commit-msg type" allin scripts/bootstrap-dev.sh 'pre-commit.* install|install.*hook' 'commit-msg|install_hook_types'

echo "== TC-T04a-12 commit-msg hook: message table (AC4, verification 'bad commit message')"
ckp "script exists: scripts/check_commit_msg.py" test -s "$S/check_commit_msg.py"
msg_rc() { local f; f=$(mktemp -p "$WORK"); printf '%b' "$1" >"$f"; python3 "$S/check_commit_msg.py" --tasks-file "$FT" --msg-file "$f"; }
ok_msg() { accepts msg_rc "$1"; }
bad_msg() { rejects msg_rc "$1"; }
LONGBODY=$(printf 'b%.0s' $(seq 1 150))
ckp "accepts 'T04a: x'" ok_msg 'T04a: x\n'
ckp "accepts 'T10: add ingest upsert endpoint' (docs example)" ok_msg 'T10: add ingest upsert endpoint\n'
ckp "accepts subject plus body with a 150-character body line" ok_msg "T04: x\n\n$LONGBODY\n"
ckp "rejects 'bad message'" bad_msg 'bad message\n'
ckp "rejects empty message" bad_msg '\n'
ckp "rejects 'T04a:x' (no space)" bad_msg 'T04a:x\n'
ckp "rejects 'T04a: ' (no text)" bad_msg 'T04a: \n'
ckp "rejects 't04: x' (lower case)" bad_msg 't04: x\n'
ckp "rejects 'T4: x' (one digit)" bad_msg 'T4: x\n'
ckp "rejects 'Initial commit' in message mode (exempt only by range)" bad_msg 'Initial commit\n'
ckp "rejects 'T04ab: x'" bad_msg 'T04ab: x\n'
ckp "rejects leading space ' T04a: x'" bad_msg ' T04a: x\n'
ckp "a rejection tells the author what is wrong" rejects_naming 'T[0-9]|task|format|prefix|subject' msg_rc 'bad message\n'

echo "== TC-T04a-13 commit-msg hook: length, Merge, Revert, fixup, unknown id (AC4, D-3)"
sub() { local n=$1 pre=$2; printf '%s%s' "$pre" "$(printf 'a%.0s' $(seq 1 $((n-${#pre}))))"; }   # subject of exactly n chars
ckp "accepts a 72-character subject (boundary)" ok_msg "$(sub 72 'T04a: ')\n"
ckp "rejects a 73-character subject (boundary)" bad_msg "$(sub 73 'T04a: ')\n"
ckp "accepts a 71-character subject" ok_msg "$(sub 71 'T10: ')\n"
ckp "accepts Merge branch ..." ok_msg "Merge branch 'task/T04a-x' into main\n"
ckp "accepts GitHub merge subject longer than 72 characters" ok_msg "Merge pull request #12 from pawan/task/T04a-coding-standards-and-quality-gates-extra\n"
ckp "accepts git revert subject Revert \"T10: x\"" ok_msg 'Revert "T10: x"\n'
ckp "rejects 'Revert it' (no quoted subject)" bad_msg 'Revert it\n'
ckp "rejects 'Merged things' (not 'Merge ')" bad_msg 'Merged things\n'
ckp "rejects 'fixup! T04a: x'" bad_msg 'fixup! T04a: x\n'
ckp "rejects 'squash! T04a: x'" bad_msg 'squash! T04a: x\n'
ckp "rejects unknown task id T99" bad_msg 'T99: x\n'
ckp "rejects T05a (not a heading in TASKS.md)" bad_msg 'T05a: x\n'
ckp "unknown id is named in the message" rejects_naming 'T99' msg_rc 'T99: x\n'
realdef() { local f; f=$(mktemp -p "$WORK"); printf '%s\n' "$1" >"$f"; python3 "$S/check_commit_msg.py" --msg-file "$f"; }
ckp "default tasks file (real docs/TASKS.md): 'T04a: x' accepted" realdef 'T04a: x'
ckp "default tasks file (real docs/TASKS.md): 'T99: x' rejected" rejects realdef 'T99: x'

echo "== TC-T04a-14 commit-msg --range in a throwaway repo: PR range only (AC4, D-3)"
RR=$WORK/range; BASE=
range_setup() { mkrepo "$RR" || return 1
  git -C "$RR" commit -q --allow-empty -m "Add files via upload that is much longer than seventy two characters in the subject line"
  git -C "$RR" commit -q --allow-empty -m "bad legacy message"
  BASE=$(git -C "$RR" rev-parse HEAD)
  git -C "$RR" commit -q --allow-empty -m "T04a: first"; git -C "$RR" commit -q --allow-empty -m "T10: second"; }
range_setup
range_run() { (cd "$RR" && python3 "$S/check_commit_msg.py" --tasks-file "$FT" --range "$BASE..HEAD"); }
ckp "good commits pass; legacy bad and over-long commits before the base are not checked" accepts range_run
addc() { git -C "$RR" commit -q --allow-empty -m "$1"; }
range_case_rej() { addc "$1"; local r=1; rejects_naming "$2" range_run && r=0; git -C "$RR" reset -q --hard HEAD~1; return "$r"; }
range_case_ok() { addc "$1"; local r=1; accepts range_run && r=0; git -C "$RR" reset -q --hard HEAD~1; return "$r"; }
ckp "range rejects a new 'bad message' commit and names it" range_case_rej 'bad message' 'bad message'
ckp "range rejects 'fixup! T04a: first'" range_case_rej 'fixup! T04a: first' 'fixup'
ckp "range rejects 'squash! T10: second'" range_case_rej 'squash! T10: second' 'squash|fixup'
ckp "range rejects a 73-character subject" range_case_rej "$(sub 73 'T10: ')" '72|long|length|T10: a'
ckp "range rejects unknown task id T99" range_case_rej 'T99: x' 'T99'
ckp "range accepts a 72-character subject" range_case_ok "$(sub 72 'T10: ')"
ckp "range accepts Revert \"T10: second\"" range_case_ok 'Revert "T10: second"'
range_merge() { local r=1; git -C "$RR" checkout -q -b side && addc "T10: side" && git -C "$RR" checkout -q main \
  && git -C "$RR" merge -q --no-ff side -m "Merge branch 'side'" && accepts range_run && r=0
  git -C "$RR" checkout -q main; git -C "$RR" reset -q --hard "$(git -C "$RR" rev-parse HEAD~1)"; git -C "$RR" branch -q -D side; return "$r"; }
ckp "range accepts a no-ff merge commit and the commits it brings" range_merge
empty_range() { (cd "$RR" && python3 "$S/check_commit_msg.py" --tasks-file "$FT" --range HEAD..HEAD); }
ckp "empty range (HEAD..HEAD) is not an error" accepts empty_range

echo "== TC-T04a-15 installed commit-msg hook in a throwaway repo (AC4, plan: 'bad message' vs 'T04a: x')"
HR=$WORK/hookrepo
mkrepo "$HR"
# shellcheck disable=SC2016 # T04a: $1 must stay literal in the generated hook
printf '#!/usr/bin/env bash\nexec python3 "%s/check_commit_msg.py" --msg-file "$1"\n' "$S" >"$HR/.git/hooks/commit-msg"
chmod +x "$HR/.git/hooks/commit-msg"
n0=$(git -C "$HR" rev-list --count HEAD 2>/dev/null || echo 0)
commit_bad() { git -C "$HR" commit --allow-empty -m "bad message"; }
commit_good() { git -C "$HR" commit --allow-empty -m "T04a: x"; }
ckp "git commit -m 'bad message' is refused" rejects commit_bad
nb() { [ "$(git -C "$HR" rev-list --count HEAD)" = "$n0" ]; }
ckp "refused commit created no commit" nb
ckp "git commit -m 'T04a: x' succeeds" accepts commit_good
na() { [ "$(git -C "$HR" rev-list --count HEAD)" = "$((n0+1))" ]; }
ckp "accepted commit exists" na

echo "== TC-T04a-16 branch naming check (AC4)"
ckp "script exists: scripts/check_branch_name.py" test -s "$S/check_branch_name.py"
br_rc() { python3 "$S/check_branch_name.py" --tasks-file "$FT" --branch "$1"; }
ok_br() { accepts br_rc "$1"; }
bad_br() { rejects br_rc "$1"; }
ckp "accepts task/T04a-coding-standards" ok_br task/T04a-coding-standards
ckp "accepts task/T10-ingest" ok_br task/T10-ingest
ckp "accepts task/T04-master-test-plan" ok_br task/T04-master-test-plan
ckp "accepts main" ok_br main
ckp "rejects feature/x" bad_br feature/x
ckp "rejects master" bad_br master
ckp "rejects task/T04a (no slug)" bad_br task/T04a
ckp "rejects task/T04a- (empty slug)" bad_br task/T04a-
ckp "rejects task/T04a-Bad-Caps" bad_br task/T04a-Bad-Caps
ckp "rejects task/T04a-two--dashes" bad_br task/T04a-two--dashes
ckp "rejects task/T04a-trailing-" bad_br task/T04a-trailing-
ckp "rejects task/t04-x (lower case id)" bad_br task/t04-x
ckp "rejects task/T4-x (one digit)" bad_br task/T4-x
ckp "rejects unknown id task/T99-x" bad_br task/T99-x
ckp "rejects task/T05a-x (not in TASKS.md)" bad_br task/T05a-x
ckp "rejects underscore slug task/T10-a_b" bad_br task/T10-a_b
ckp "rejects nested path task/T10-a/b" bad_br task/T10-a/b
env_br() { (cd "$WORK" && env GITHUB_HEAD_REF="$1" python3 "$S/check_branch_name.py" --tasks-file "$FT"); }
ckp "CI: GITHUB_HEAD_REF=task/T10-ingest accepted" accepts env_br task/T10-ingest
ckp "CI: GITHUB_HEAD_REF=feature/x rejected" rejects env_br feature/x
git_br() { (cd "$HR" && env -u GITHUB_HEAD_REF python3 "$S/check_branch_name.py"); }
gb_bad() { local r; git -C "$HR" checkout -q -b feature/bad; rejects git_br; r=$?; git -C "$HR" checkout -q main; return "$r"; }
gb_ok() { local r; git -C "$HR" checkout -q -b task/T04a-demo; accepts git_br; r=$?; git -C "$HR" checkout -q main; return "$r"; }
ckp "no argument, no env: current git branch feature/bad rejected" gb_bad
ckp "no argument, no env: current git branch task/T04a-demo accepted" gb_ok

echo "== TC-T04a-17 exceptions report: an untagged suppression fails, per tool (AC6)"
ckp "script exists: scripts/exceptions_report.py" test -s "$S/exceptions_report.py"
# D-4 addendum (2026-11-01): the ticket goes in the tool's own comment slot after its separator.
# tool|file|untagged line|correct form (accepted)|bare or forbidden form (rejected). '-' = no accepted form.
TOOLS=(
'noqa|a.py|import os  # noqa: F401|import os  # noqa: F401  # T32: legacy|import os  # noqa: F401  T32: legacy'
'type: ignore|b.py|x: int = "s"  # type: ignore[assignment]|x: int = "s"  # type: ignore[assignment]  # T32: legacy|x: int = "s"  # type: ignore[assignment]  T32: legacy'
'pragma: no cover|c.py|def f() -> None:  # pragma: no cover|def f() -> None:  # pragma: no cover  # T32: legacy|def f() -> None:  # pragma: no cover  T32: legacy'
'eslint-disable|d.ts|// eslint-disable-next-line no-console|// eslint-disable-next-line no-console -- T32: legacy|// eslint-disable-next-line no-console T32: legacy'
'@ts-expect-error|e.ts|// @ts-expect-error|// @ts-expect-error T32: legacy|// @ts-ignore T32: legacy'
'phpcs:ignore|f.php|// phpcs:ignore Drupal.Commenting.FunctionComment.Missing|// phpcs:ignore Drupal.Commenting.FunctionComment.Missing -- T32: legacy|// phpcs:ignore Drupal.Commenting.FunctionComment.Missing T32: legacy'
'@phpstan-ignore|g.php|// @phpstan-ignore method.notFound|// @phpstan-ignore method.notFound (T32: legacy)|// @phpstan-ignore method.notFound T32: legacy'
'shellcheck|h.sh|# shellcheck disable=SC2034|# shellcheck disable=SC2034 # T32: legacy|# shellcheck disable=SC2034 T32: legacy'
'yamllint|i.yaml|# yamllint disable-line rule:line-length|-|# yamllint disable-line rule:line-length # T32: legacy'
'markdownlint|j.md|<!-- markdownlint-disable-next-line MD013 -->|<!-- markdownlint-disable-next-line MD013 --> <!-- T32: legacy -->|<!-- markdownlint-disable-next-line MD013 T32: legacy -->'
'hadolint|Dockerfile|# hadolint ignore=DL3008|# hadolint ignore=DL3008 # T32: legacy|# hadolint ignore=DL3008 T32: legacy'
)
ex_run() { (cd "$1" && git add -A && git commit -qm "fixture" --allow-empty && python3 "$S/exceptions_report.py" --out "$1/exc-report.txt"); }
ex_line() { local file=$1 line=$2 d="$WORK/ex_$RANDOM$RANDOM"; mkrepo "$d" || return 1; put "$d/$file" "$line"; ex_run "$d"; }
cleanrepo() { local d=$WORK/ex_clean; mkrepo "$d" && put "$d/ok.py" 'x: int = 1' && ex_run "$d"; }
ckp "control: fixture repo with no suppressions passes" accepts cleanrepo
for row in "${TOOLS[@]}"; do IFS='|' read -r tool file untag good bare <<<"$row"
  ckp "untagged '$tool' in $file is rejected" rejects ex_line "$file" "$untag"
done
exfile_named() { local d=$WORK/ex_named; mkrepo "$d" && put "$d/pkg/mod.py" "$(printf 'a = 1\nimport os  # noqa: F401')" && git -C "$d" add -A && git -C "$d" commit -qm f \
  && (cd "$d" && python3 "$S/exceptions_report.py" --out "$d/r.txt"); }
ckp "failure names file and line (pkg/mod.py:2)" rejects_naming 'pkg/mod\.py.?:?.?2' exfile_named

echo "== TC-T04a-18 exceptions report: tagged suppressions pass and are counted; tag rules (AC6, D-4)"
for row in "${TOOLS[@]}"; do IFS='|' read -r tool file untag good bare <<<"$row"
  if [ "$good" = "-" ]; then
    ckp "'$tool': no accepted inline form exists (a ticket after the directive is rejected)" rejects ex_line "$file" "$bare"
  else
    ckp "correct form of '$tool' (ticket in the tool's comment slot) is accepted" accepts ex_line "$file" "$good"
    ckp "bare or forbidden form of '$tool' is rejected (D-4 addendum)" rejects ex_line "$file" "$bare"
  fi
done
ckp "noqa without a code is rejected even with a ticket" rejects ex_line a.py 'import os  # noqa  # T32: legacy'
ckp "eslint-disable naming no rule is rejected even with a ticket" rejects ex_line d.ts '// eslint-disable-next-line -- T32: legacy'
ckp "inline yamllint disable (block form) is rejected even with a ticket in a comment" rejects ex_line i.yaml '# yamllint disable rule:line-length # T32: legacy'
ckp "ticket only in a docstring-style comment far from the directive is rejected" rejects ex_line a.py 'import os  # T32: legacy  # noqa: F401'
exmany() { local d=$WORK/ex_many; mkrepo "$d" || return 1
  put "$d/a.py" "$(printf 'import os  # noqa: F401  # T32: legacy\nimport sys  # noqa: F401  # T04a: legacy\ny: int = "s"  # type: ignore[assignment]  # DEF-001: x')"
  put "$d/h.sh" '# shellcheck disable=SC2034 # T32: legacy'
  ex_run "$d" || return 1
  grep -iE 'noqa' "$d/exc-report.txt" | grep -qE '\b2\b' || { echo "noqa count 2 not in report"; return 1; }
  grep -iE 'type: ?ignore' "$d/exc-report.txt" | grep -qE '\b1\b' || { echo "type: ignore count 1 not in report"; return 1; }
  grep -iE 'shellcheck' "$d/exc-report.txt" | grep -qE '\b1\b' || { echo "shellcheck count 1 not in report"; return 1; }
  grep -qE 'T32' "$d/exc-report.txt" || { echo "ticket not listed"; return 1; }; }
ckp "report file counts per tool (noqa 2, type: ignore 1, shellcheck 1) and lists tickets" exmany
tagcase() { local d=$WORK/ex_tag_$RANDOM; mkrepo "$d" || return 1; put "$d/a.py" "$1"; ex_run "$d"; }
ckp "accepts DEF-001 (exists in defects.md)" accepts tagcase 'import os  # noqa: F401  # DEF-001: core stub'
ckp "rejects DEF-999 (not in defects.md)" rejects tagcase 'import os  # noqa: F401  # DEF-999: x'
ckp "rejects T99 (not in TASKS.md)" rejects tagcase 'import os  # noqa: F401  # T99: x'
ckp "rejects a ticket with no reason ('T32' alone)" rejects tagcase 'import os  # noqa: F401  # T32'
ckp "rejects no space after the colon ('T32:x')" rejects tagcase 'import os  # noqa: F401  # T32:x'
ckp "rejects lower-case ticket 't32: x'" rejects tagcase 'import os  # noqa: F401  # t32: x'
ckp "accepts 'T04a: reason' (sub-task id)" accepts tagcase 'import os  # noqa: F401  # T04a: captured output'
ckp "rejects the bare form 'noqa: F401  T32: x' (ruff would drop the directive)" rejects tagcase 'import os  # noqa: F401  T32: x'
ckp "rejects a ticket on a different line from the suppression" rejects tagcase "$(printf '# T32: reason on another line\nimport os  # noqa: F401')"
ckp "rejects a ticket on the next line only (same-line rule)" rejects tagcase "$(printf 'import os  # noqa: F401\n# T32: reason')"
cfg_case() { local d=$WORK/ex_cfg_$RANDOM; mkrepo "$d" || return 1; put "$d/$1" "$2"; ex_run "$d"; }
ckp "config path exclude without ticket rejected (.markdownlint-cli2.yaml ignores)" rejects cfg_case .markdownlint-cli2.yaml "$(printf 'ignores:\n  - "docs/TASKS.md"')"
ckp "config path exclude with ticket accepted" accepts cfg_case .markdownlint-cli2.yaml "$(printf 'ignores:\n  - "docs/TASKS.md"  # T32: owner document')"
ckp "ruff exclude without ticket rejected" rejects cfg_case ruff.toml 'exclude = ["docs/tests/*/evidence"]'
ckp "ruff exclude with ticket accepted" accepts cfg_case ruff.toml 'exclude = ["docs/tests/*/evidence"]  # T04a: captured output'
ckp "yamllint per-rule ignore path without ticket rejected (the yamllint exception form)" rejects cfg_case .yamllint.yaml "$(printf 'rules:\n  line-length:\n    ignore:\n      - docs/x.yaml')"
ckp "yamllint per-rule ignore path with a YAML comment ticket accepted" accepts cfg_case .yamllint.yaml "$(printf 'rules:\n  line-length:\n    ignore:\n      - docs/x.yaml  # T32: legacy')"
ckp "Spectral overrides rule off without ticket rejected" rejects cfg_case .spectral.yaml "$(printf 'overrides:\n  - files: ["openapi.yaml#/paths"]\n    rules:\n      oas3-schema: "off"')"
ckp "Spectral overrides rule off with a ticket comment accepted" accepts cfg_case .spectral.yaml "$(printf 'overrides:\n  - files: ["openapi.yaml#/paths"]\n    rules:\n      oas3-schema: "off"  # T32: legacy')"

echo "== TC-T04a-19 coverage gate: floors and boundaries on Cobertura fixtures (AC7, verification 'coverage drop')"
ckp "script exists: scripts/coverage_gate.py" test -s "$S/coverage_gate.py"
mkcov() { python3 -I - "$@" <<'PY'
import sys
out, specs = sys.argv[1], sys.argv[2:]          # spec = path:total:hit:branchrate
tot = hit = 0; classes = []
for s in specs:
    p, n, h, b = s.split(":"); n, h = int(n), int(h); tot += n; hit += h
    ls = "".join(f'<line number="{i+1}" hits="{1 if i < h else 0}"/>' for i in range(n))
    classes.append(f'<class name="{p}" filename="{p}" line-rate="{h/n}" branch-rate="{b}" complexity="0"><methods/><lines>{ls}</lines></class>')
doc = (f'<?xml version="1.0" ?><coverage version="7.6" timestamp="0" line-rate="{hit/tot if tot else 0}" branch-rate="0.5" '
       f'lines-covered="{hit}" lines-valid="{tot}" branches-covered="0" branches-valid="0" complexity="0">'
       f'<sources><source>/repo</source></sources><packages><package name="p" line-rate="0" branch-rate="0" complexity="0"><classes>'
       + "".join(classes) + '</classes></package></packages></coverage>')
open(out, "w").write(doc)
PY
}
gate() { python3 "$S/coverage_gate.py" --thresholds "${T04A_THRESHOLDS:-$ROOT/quality/coverage-thresholds.json}" "$1"; }
ESC=meridian_engine/scoring/rules.py; ERK=meridian_engine/risk/limits.py; EDT=meridian_engine/data/util.py
gcase() { local f=$WORK/cov_$RANDOM.xml; mkcov "$f" "$@" || return 1; gate "$f"; }
gcase_rej() { local pat=$1; shift; rejects_naming "$pat" gcase "$@"; }
ckp "all above floors (scoring 95, risk 95, other 90): accepted" accepts gcase "$ESC:100:95:0.5" "$ERK:100:95:0.5" "$EDT:100:90:0.5"
ckp "scoring 89 percent rejected and the file is named" gcase_rej 'scoring/rules\.py' "$ESC:100:89:0.5" "$ERK:100:95:0.5" "$EDT:100:100:0.5"
ckp "scoring exactly 90 accepted (floor is inclusive)" accepts gcase "$ESC:100:90:0.5" "$ERK:100:95:0.5" "$EDT:100:90:0.5"
ckp "risk 89 rejected and the file is named" gcase_rej 'risk/limits\.py' "$ESC:100:95:0.5" "$ERK:100:89:0.5" "$EDT:100:100:0.5"
ckp "risk exactly 90 accepted" accepts gcase "$ESC:100:95:0.5" "$ERK:100:90:0.5" "$EDT:100:90:0.5"
ckp "overall engine 83.3 percent rejected (scoring and risk fine, other 60)" gcase_rej 'meridian_engine|util\.py|overall' "$ESC:100:95:0.5" "$ERK:100:95:0.5" "$EDT:100:60:0.5"
ckp "overall engine exactly 85 accepted" accepts gcase "$ESC:100:95:0.5" "$ERK:100:90:0.5" "$EDT:100:70:0.5"
ckp "a drop (scoring 95 -> 70) is rejected: the regression the criterion names" gcase_rej 'scoring' "$ESC:100:70:0.5" "$ERK:100:95:0.5" "$EDT:100:95:0.5"

echo "== TC-T04a-20 coverage gate: line rate not branch, other components, malformed input (AC7, D-1)"
ckp "line 95 with branch rate 0.10 accepted (gate reads the line rate)" accepts gcase "$ESC:100:95:0.10" "$ERK:100:95:0.10" "$EDT:100:95:0.10"
ckp "line 85 with branch rate 1.0 rejected (branch cannot rescue lines)" gcase_rej 'scoring' "$ESC:100:85:1.0" "$ERK:100:95:1.0" "$EDT:100:95:1.0"
DR=web/modules/custom/meridian_ingest/src/Ingest.php
ckp "Drupal custom 69 percent rejected" gcase_rej 'meridian_ingest|Ingest\.php' "$DR:100:69:0"
ckp "Drupal custom exactly 70 accepted" accepts gcase "$DR:100:70:0"
ckp "web lib 79 rejected" gcase_rej 'lib/format\.ts' "apps/web/lib/format.ts:100:79:0"
ckp "web lib exactly 80 accepted" accepts gcase "apps/web/lib/format.ts:100:80:0"
ckp "web components 79 rejected" gcase_rej 'components/Table\.tsx' "apps/web/components/Table.tsx:100:79:0"
ckp "web app/ routes have no unit floor (10 percent accepted)" accepts gcase "apps/web/lib/format.ts:100:90:0" "apps/web/app/page.tsx:100:10:0"
badxml() { printf '<coverage><packages>' >"$WORK/bad.xml"; gate "$WORK/bad.xml"; }
emptyxml() { printf '<?xml version="1.0" ?><coverage line-rate="0" branch-rate="0"><packages/></coverage>' >"$WORK/empty.xml"; gate "$WORK/empty.xml"; }
missingxml() { gate "$WORK/does-not-exist.xml"; }
ckp "malformed XML rejected, not a traceback" rejects badxml
ckp "coverage report with no files rejected (no vacuous pass)" rejects emptyxml
ckp "missing coverage file rejected" rejects missingxml

echo "== TC-T04a-21 asset check rejects third-party hosts and hard-coded hex (verification, section 0b)"
ckp "script exists: scripts/check_assets.py" test -s "$S/check_assets.py"
asset_case() { local file=$1 body=$2 d=$WORK/as_$RANDOM$RANDOM; mkrepo "$d" || return 1; put "$d/$file" "$body"
  git -C "$d" add -A; git -C "$d" commit -qm f; (cd "$d" && python3 "$S/check_assets.py"); }
W=apps/web/app
ckp "control: a page with only same-origin assets passes" accepts asset_case $W/layout.tsx '<link rel="stylesheet" href="/fonts/inter.css" />'
ckp "rejects fonts.googleapis.com <link>" rejects asset_case $W/layout.tsx '<link href="https://fonts.googleapis.com/css2?family=Inter" rel="stylesheet" />'
ckp "rejects fonts.gstatic.com in CSS url()" rejects asset_case $W/globals.css '@font-face { src: url(https://fonts.gstatic.com/s/inter.woff2); }'
ckp "rejects script from cdn.jsdelivr.net" rejects asset_case $W/layout.tsx '<script src="https://cdn.jsdelivr.net/npm/x.js"></script>'
ckp "rejects script from unpkg.com" rejects asset_case $W/layout.tsx '<script src="https://unpkg.com/x"></script>'
ckp "rejects @import from cdnjs.cloudflare.com" rejects asset_case $W/globals.css '@import url("https://cdnjs.cloudflare.com/x.css");'
ckp "rejects icon stylesheet from use.fontawesome.com" rejects asset_case $W/layout.tsx '<link rel="stylesheet" href="https://use.fontawesome.com/releases/x.css">'
ckp "rejects protocol-relative //fonts.googleapis.com" rejects asset_case $W/layout.tsx '<link href="//fonts.googleapis.com/css" rel="stylesheet" />'
ckp "rejects hex #1a2b3c in app CSS" rejects asset_case $W/globals.css 'body { color: #1a2b3c; }'
ckp "rejects short hex #fff in app CSS" rejects asset_case $W/globals.css 'body { background: #fff; }'
ckp "rejects 8-digit hex #1a2b3cff" rejects asset_case $W/globals.css 'a { color: #1a2b3cff; }'
ckp "rejects hex in TSX inline style" rejects asset_case $W/page.tsx 'export const s = { color: "#ff0000" };'
ckp "rejects third-party font in the Drupal custom theme" rejects asset_case apps/drupal/web/themes/custom/meridian_theme/css/base.css '@import url("https://fonts.googleapis.com/css2?family=Inter");'
ckp "rejects hex in the Drupal custom theme" rejects asset_case apps/drupal/web/themes/custom/meridian_theme/css/base.css 'body { color: #123456; }'
ckp "failure names the file" rejects_naming 'globals\.css' asset_case $W/globals.css 'body { color: #1a2b3c; }'

echo "== TC-T04a-22 asset check accepts legitimate use and ignores out-of-scope files (no false positives)"
ckp "accepts same-origin font url(/fonts/inter.woff2)" accepts asset_case $W/globals.css '@font-face { src: url(/fonts/inter.woff2); }'
ckp "accepts CSS variables" accepts asset_case $W/globals.css 'body { color: var(--color-fg); }'
ckp "accepts in-page anchor href=\"#main-content\"" accepts asset_case $W/layout.tsx '<a href="#main-content">Skip</a>'
ckp "accepts HTML entity &#39; (not a colour)" accepts asset_case $W/page.tsx 'export const t = "it&#39;s";'
ckp "accepts an external documentation link (not an asset)" accepts asset_case $W/page.tsx '<a href="https://example.org/doc">Docs</a>'
ckp "ignores docs/ (fonts.googleapis.com in Markdown is out of scope)" accepts asset_case docs/note.md 'We do not use https://fonts.googleapis.com/css.'
ckp "ignores services/engine files" accepts asset_case services/engine/x.py 'U = "https://fonts.googleapis.com/css"  # colour #ffffff'
tokpath() { grep -ohE 'apps/web/[A-Za-z0-9_./-]*tokens[A-Za-z0-9_.-]*' "$S/check_assets.py" "$S/README.md" 2>/dev/null | head -1; }
tokens_ok() { local p; p=$(tokpath); [ -n "$p" ] || { echo "tokens file path not documented in check_assets.py or scripts/README.md"; return 1; }
  asset_case "$p" ':root { --color-bg: #0b1020; --color-fg: #e8ecf5; }'; }
ckp "hex inside the tokens file (path read from the script) is accepted" tokens_ok

echo "== TC-T04a-23 scripts/quality.sh: static contract (AC5)"
QS=$S/quality.sh
ckp "quality.sh exists and is executable" exists_x "$QS"
ckp "quality.sh passes bash -n" bash -n "$QS"
shebang() { head -1 "$1" | grep -qE '^#!/usr/bin/env bash|^#!/bin/bash'; }
ckp "starts with a bash shebang" shebang "$QS"
ckp "runs pre-commit, branch, commit range, exceptions, assets, coverage gate" allin "$QS" 'pre-commit' 'check_branch_name' 'check_commit_msg' 'exceptions_report' 'check_assets' 'coverage_gate'
ckp "component manifests keyed: engine pyproject, drupal composer.json, web package.json" allin "$QS" 'services/engine/pyproject\.toml' 'apps/drupal/composer\.json' 'apps/web/package\.json'
ckp "commit range against origin/main" allin "$QS" 'origin/main'
ckp "prints PASS, FAIL and SKIP and honours QUALITY_RUNNER and QUALITY_STEPS" allin "$QS" '\bPASS\b' '\bFAIL\b' '\bSKIP\b' 'QUALITY_RUNNER' 'QUALITY_STEPS'
noswallow() { [ -s "$QS" ] && ! grep -nE '\|\| *true' "$QS" | grep -vE '^[0-9]+: *#'; }
ckp "no silent swallowing: no '|| true' on a code line" noswallow

echo "== TC-T04a-24 quality.sh with fake steps: PASS, FAIL, SKIP and the exit code (AC5)"
mkdir -p "$WORK/q"; : >"$WORK/q/present.manifest"
qs_run() {   # adapter A-3: steps-file content -> runs quality.sh, prints its output, returns its exit code
  printf '%b' "$1" >"$WORK/q/steps"; QUALITY_STEPS="$WORK/q/steps" QUALITY_RUNNER="${2:-native}" bash "$QS" 2>&1; }
qline() { printf 'qs_%s\t%s\t%s\\n' "$1" "$2" "$3"; }
OKSTEP=$(qline ok1 - true); BADSTEP=$(qline bad1 - false); OK2=$(qline ok2 - true)
SKIPSTEP=$(qline skip1 "$WORK/q/absent.manifest" false)
MISSSTEP=$(qline miss1 "$WORK/q/present.manifest" meridian-no-such-tool-xyz)
FAILPRES=$(qline fail1 "$WORK/q/present.manifest" false)
run_ok()  { local o rc; o=$(qs_run "$1"); rc=$?; printf '%s\n' "$o"; [ "$rc" -eq 0 ]; }
run_bad() { local o rc; o=$(qs_run "$1"); rc=$?; printf '%s\n' "$o"; [ "$rc" -ne 0 ]; }
t1() { local o; o=$(run_ok "$OKSTEP") || return 1; grep -qE 'PASS.*qs_ok1' <<<"$o"; }
ckp "all steps pass: exit 0 and a PASS line for the step" t1
t2() { local o; o=$(run_ok "$OKSTEP$SKIPSTEP") || return 1; grep -qE 'PASS.*qs_ok1' <<<"$o" && grep -qE 'SKIP.*qs_skip1' <<<"$o" && ! grep -qE 'FAIL.*qs_' <<<"$o"; }
ckp "manifest absent: SKIP (its command would have failed), exit 0, no FAIL line" t2
t3() { local o; o=$(run_bad "$OKSTEP$BADSTEP$OK2") || return 1; grep -qE 'PASS.*qs_ok1' <<<"$o" && grep -qE 'FAIL.*qs_bad1' <<<"$o" && grep -qE 'PASS.*qs_ok2' <<<"$o"; }
ckp "one failing step: exit non-zero, FAIL shown, later steps still run" t3
t4() { local o; o=$(run_bad "$MISSSTEP") || return 1; grep -qE 'FAIL.*qs_miss1' <<<"$o" && ! grep -qE 'SKIP.*qs_miss1' <<<"$o"; }
ckp "tool missing with manifest present: FAIL (not SKIP), exit non-zero" t4
t5() { local o; o=$(run_bad "$FAILPRES") || return 1; grep -qE 'FAIL.*qs_fail1' <<<"$o"; }
ckp "manifest present and the command fails: FAIL, exit non-zero" t5
t6() { local o; o=$(run_bad "$OKSTEP$SKIPSTEP$BADSTEP") || return 1; grep -q FAIL <<<"$o" && grep -q SKIP <<<"$o" && grep -q PASS <<<"$o"; }
ckp "mixed run: exit non-zero although some steps pass and some SKIP" t6
t7() { local o; o=$(run_bad "$OKSTEP$SKIPSTEP$BADSTEP") || return 1; grep -E 'PASS' <<<"$o" | grep -E 'FAIL' | grep -E 'SKIP' | grep -qE '[0-9]'; }
ckp "summary line has PASS, FAIL and SKIP counts" t7
t8() { local o; o=$(run_ok "$SKIPSTEP") || return 1; grep -qE 'SKIP.*qs_skip1' <<<"$o"; }
ckp "only SKIP steps: exit 0 (T08 asserts expected components, not this script)" t8
t9() { qs_run "$OKSTEP" bogus; }
ckp "unknown QUALITY_RUNNER rejected with a message naming the runner (native or ddev)" rejects_naming 'runner|native|ddev' t9

echo "== TC-T04a-25 .ddev/commands/host/quality wrapper (AC5; ddev quality itself is TC-48)"
WR=.ddev/commands/host/quality
ckp "wrapper exists and is executable" exists_x "$WR"
ckp "wrapper has a bash shebang" shebang "$WR"
# shellcheck disable=SC2016 # T04a: fixed-string pattern, $-variables must stay literal
ckp "wrapper execs scripts/quality.sh with the arguments" gF "$WR" 'exec "$DDEV_APPROOT/scripts/quality.sh" "$@"'
ckp "wrapper has the DDEV '## Description' header" g "$WR" '^## Description:'
wrap() { printf '%b' "$1" >"$WORK/q/wsteps"; DDEV_APPROOT="$ROOT" QUALITY_STEPS="$WORK/q/wsteps" QUALITY_RUNNER=native bash "$WR"; }
ckp "wrapper propagates failure (fake FAIL step: non-zero exit, FAIL printed)" rejects_naming 'FAIL' wrap "$BADSTEP"
ckp "wrapper propagates success (fake PASS step: exit 0)" accepts wrap "$OKSTEP"

echo "== TC-T04a-26 script tests, typing proxy and Python 3.10 compatibility (AC3, verification 'untyped Python')"
has_tests() { [ -f "$1" ] && [ "$(grep -cE '^\s+def test_' "$1")" -ge 3 ]; }
for n in check_commit_msg check_branch_name exceptions_report coverage_gate check_assets; do
  ckp "scripts/tests/test_$n.py exists with at least 3 tests" has_tests "scripts/tests/test_$n.py"
done
ckp "python3 -m unittest discover -s scripts/tests passes" python3 -m unittest discover -s scripts/tests
compile_all() { shopt -s nullglob; local f=(scripts/*.py scripts/tests/*.py); [ ${#f[@]} -ge 10 ] && python3 -m py_compile "${f[@]}"; }
ckp "all scripts/*.py compile on this Python ($(python3 --version 2>&1))" compile_all
untyped() { python3 -I - "$@" <<'PY'
import ast, sys
bad = []
for p in sys.argv[1:]:
    for n in ast.walk(ast.parse(open(p).read())):
        if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)):
            a = n.args; args = a.posonlyargs + a.args + a.kwonlyargs + ([a.vararg] if a.vararg else []) + ([a.kwarg] if a.kwarg else [])
            miss = [x.arg for x in args if x.annotation is None and x.arg not in ("self", "cls")]
            if n.returns is None or miss: bad.append(f"{p}:{n.lineno} {n.name}")
print("\n".join(bad)); sys.exit(1 if bad else 0)
PY
}
selftest_untyped() { printf 'def add(a, b):\n    return a + b\n' >"$WORK/u.py"; printf 'def add(a: int, b: int) -> int:\n    return a + b\n' >"$WORK/t.py"
  ! untyped "$WORK/u.py" >/dev/null && untyped "$WORK/t.py" >/dev/null; }
ckp "typing proxy self-test: untyped file flagged, typed file clean" selftest_untyped
allfiles() { shopt -s nullglob; local f=(scripts/*.py scripts/tests/*.py .claude/hooks/*.py .claude/hooks/tests/*.py); [ ${#f[@]} -ge 10 ] && untyped "${f[@]}"; }
ckp "every function in scripts/ and .claude/hooks/ is fully annotated (proxy for mypy --strict)" allfiles

echo "== TC-T04a-27 baseline: project-authored Markdown has no line over 100 characters (AC6, verification 'long Markdown line')"
mdlen() { python3 -I - "$@" <<'PY'
import re, sys
bad = []
for p in sys.argv[1:]:
    fence = False; fm = False
    for n, line in enumerate(open(p, encoding="utf-8"), 1):
        s = line.rstrip("\n")
        if n == 1 and s.rstrip() == "---": fm = True; continue          # YAML front matter, as markdownlint
        if fm:
            if s.rstrip() in ("---", "..."): fm = False
            continue
        if re.match(r"\s*(```|~~~)", s): fence = not fence; continue
        if fence or s.lstrip().startswith("|") or s.startswith("#"): continue
        if len(s) > 100 and re.match(r"^.{100}.*\s", s): bad.append(f"{p}:{n} ({len(s)})")
for b in bad[:12]: print(b)
print(f"{len(bad)} line(s) over 100 characters in {len(sys.argv) - 1} files"); sys.exit(1 if bad else 0)
PY
}
mdself() { printf '%s\n' "$(printf 'word %.0s' $(seq 1 40))" >"$WORK/long.md"
  # shellcheck disable=SC2016 # T04a: backticks are literal markdown fence text
  printf '| %s |\n```\n%s\n```\n# %s\nhttps://%s\n' "$(printf 'c%.0s' $(seq 1 130))" "$(printf 'x%.0s' $(seq 1 130))" "$(printf 'h%.0s' $(seq 1 130))" "$(printf 'u%.0s' $(seq 1 130))" >"$WORK/exempt.md"
  ! mdlen "$WORK/long.md" >/dev/null && mdlen "$WORK/exempt.md" >/dev/null; }
ckp "checker self-test: prose line flagged; table, code, heading and bare URL exempt" mdself
mdfm() { local long; long=$(printf 'word %.0s' $(seq 1 40))
  printf -- '---\ndescription: %s\n---\n# Title\n\nshort\n' "$long" >"$WORK/fm.md"
  printf 'intro\n\n---\ndescription: %s\n---\n' "$long" >"$WORK/notfm.md"
  printf -- '---\ndescription: %s\n---\n\n%s\n' "$long" "$long" >"$WORK/fm_then_prose.md"
  mdlen "$WORK/fm.md" >/dev/null && ! mdlen "$WORK/notfm.md" >/dev/null && ! mdlen "$WORK/fm_then_prose.md" >/dev/null; }
ckp "checker self-test: leading YAML front matter exempt; '---' later in a file and prose after front matter still flagged" mdfm
mdscan() { local F; mapfile -t F < <(git ls-files -co --exclude-standard -- '*.md' | grep -vE '^docs/TASKS\.md$|^docs/tests/[^/]+/evidence/'); [ ${#F[@]} -ge 50 ] || { echo "too few files (${#F[@]})"; return 1; }; mdlen "${F[@]}"; }
ckp "all project-authored Markdown (excluding docs/TASKS.md and evidence) within 100 characters" mdscan
mdnew() { mdlen "$SA" "$RC" "$T/test-cases.md" docs/tasks/T04a/plan.md docs/tasks/T04a/decision-t04a-standards.md; }
ckp "the T04a documents themselves are within 100 characters" mdnew

echo "== TC-T04a-28 exclusions carry a ticket; TASKS.md exclusion cites T32 (AC6, interim Q1)"
TICKET_RE='\b(T[0-9]{2}a?|DEF-[0-9]{3}): [^ ]'
line_has_ticket() { grep -E "$2" "$1" | grep -qE "$TICKET_RE"; }
ckp "T32 is a heading in docs/TASKS.md" grep -qE '^## T32:' docs/TASKS.md
ckp "markdownlint config excludes docs/TASKS.md on a line citing T32" line_has_ticket "$MD_CFG" 'TASKS\.md'
ckp "markdownlint config excludes docs/tests/*/evidence on a line citing a ticket" line_has_ticket "$MD_CFG" 'evidence'
ckp "ruff.toml excludes evidence on a line citing a ticket" line_has_ticket ruff.toml 'evidence'
t32line() { grep -E 'TASKS\.md' "$MD_CFG" | grep -qE '\bT32: [^ ]'; }
ckp "the TASKS.md exclusion cites T32 specifically" t32line
allexcl() { python3 -I - "$MD_CFG" <<'PY'
import re, sys
bad = []; ig = []; inb = False
for l in open(sys.argv[1]).read().splitlines():
    if l.startswith("ignores:"): inb = True; continue
    if inb and re.match(r"^\S", l): inb = False
    if inb and re.match(r"\s*- ", l):
        ig.append(l)
        if not re.search(r"\b(T\d{2}a?|DEF-\d{3}): \S", l): bad.append("no ticket: " + l.strip())
        if not re.search(r"TASKS\.md|evidence", l): bad.append("unexpected exclusion: " + l.strip())
if len(ig) < 2: bad.append(f"expected the TASKS.md and evidence exclusions, found {len(ig)}")
print("\n".join(bad)); sys.exit(1 if bad else 0)
PY
}
ckp "markdownlint 'ignores': only TASKS.md and evidence, each with a ticket" allexcl

echo "== TC-T04a-29 exceptions report on the real tree (AC6)"
REP=$WORK/real-exceptions.txt
realex() { python3 "$S/exceptions_report.py" --out "$REP" && [ -s "$REP" ]; }
ckp "exceptions_report.py exits 0 on the real tree and writes a non-empty report" realex
indep() { python3 -I - "$REP" <<'PY'
import re, subprocess, sys
files = subprocess.run(["git", "ls-files", "-co", "--exclude-standard"], capture_output=True, text=True).stdout.split("\n")
code = re.compile(r"\.(py|sh|ts|tsx|js|mjs|php|module|inc|ya?ml|toml|ini|cfg|neon)$|(^|/)Dockerfile")
TK = r"(?:T\d{2}a?|DEF-\d{3}): \S"          # D-4 addendum: the ticket must follow the tool's own separator
tok = {"noqa": r"#\s*noqa", "type: ignore": r"#\s*type:\s*ignore", "pragma: no cover": r"#\s*pragma:\s*no cover",
       "eslint-disable": r"(//|/\*)\s*eslint-disable", "@ts-expect-error": r"(//|/\*)\s*@ts-expect-error",
       "phpcs:ignore": r"(//|#|/\*)\s*phpcs:ignore", "@phpstan-ignore": r"@phpstan-ignore", "shellcheck": r"#\s*shellcheck\s+disable",
       "yamllint": r"#\s*yamllint\s+disable", "markdownlint": r"^\s*<!--\s*markdownlint-disable", "hadolint": r"#\s*hadolint\s+ignore",
       "@ts-ignore": r"@ts-ignore"}
# per tool: the regex the whole line must match to count as correctly ticketed (None = never allowed)
ok_form = {"noqa": r"#\s*noqa:\s*[A-Z]+[0-9]+(?:[,\s]+[A-Z]+[0-9]+)*\s+#\s*" + TK,
           "type: ignore": r"type:\s*ignore\[[^\]#]+\]\s+#\s*" + TK,
           "pragma: no cover": r"pragma:\s*no cover\s+#\s*" + TK,
           "shellcheck": r"shellcheck\s+disable=\S+\s+#\s*" + TK,
           "hadolint": r"hadolint\s+ignore=\S+\s+#\s*" + TK,
           "eslint-disable": r"eslint-disable\S*\s+[@\w/-]+.*\s--\s+" + TK,
           "phpcs:ignore": r"phpcs:ignore\s+\S+.*\s--\s+" + TK,
           "@phpstan-ignore": r"@phpstan-ignore\s+\S+\s+\(" + TK,
           "@ts-expect-error": r"@ts-expect-error\s+" + TK,
           "markdownlint": r"-->\s*<!--\s*" + TK,
           "yamllint": None, "@ts-ignore": None}
skip = re.compile(r"^(scripts/exceptions_report\.py|scripts/tests/|docs/tasks/|docs/tests/T04a/|docs/tests/[^/]+/evidence/)")
ticket = None
counts = {k: 0 for k in tok}; untagged = []
for f in files:
    if not f or skip.match(f) or not (code.search(f) or f.endswith(".md")): continue
    try: lines = open(f, encoding="utf-8").read().splitlines()
    except (OSError, UnicodeDecodeError): continue
    for n, l in enumerate(lines, 1):
        for k, rx in tok.items():
            if k == "markdownlint" and not f.endswith(".md"): continue
            if re.search(rx, l):
                counts[k] += 1
                form = ok_form[k]
                if form is None or not re.search(form, l): untagged.append(f"{f}:{n}: {k} (no ticket in the tool's comment slot)")
rep = open(sys.argv[1]).read()
errs = [f"untagged: {u}" for u in untagged[:8]]
for k, c in counts.items():
    if c and not any(k.lower() in l.lower() and re.search(rf"\b{c}\b", l) for l in rep.splitlines()):
        errs.append(f"report lacks count {c} for {k}")
print("independent counts:", {k: v for k, v in counts.items() if v}); print("\n".join(errs)); sys.exit(1 if errs else 0)
PY
}
ckp "independent scan: every suppression cites a ticket; report counts equal the scan" indep
has_t32() { grep -q 'T32' "$REP"; }
ckp "report lists the TASKS.md exclusion and its ticket T32" has_t32

echo "== TC-T04a-30 helper regression after the baseline cleanup (T01 guard, T03 and T04 checks behave the same)"
ckp "T01 guard unit tests pass" python3 -m unittest discover -s .claude/hooks/tests
# DEF-005: regression means "no earlier check got worse": no FAIL line, exit 0 and PASS >= the count
# recorded at close. A SKIP turning into PASS is not a regression; a PASS dropping is.
count_ok() {   # LABEL RC PASS_NOW PASS_AT_CLOSE FAIL_LINES
  echo "$1: exit $2, PASS now $3, at close $4, FAIL lines $5"
  [ "$2" -eq 0 ] && [ "$5" -eq 0 ] && [ "$3" -ge "$4" ]; }
same_count() { local task=$1 mode=$2 ev=$3 out n e rc f; out=$(docs/tests/"$task"/run-checks.sh ${mode:+"$mode"} 2>&1); rc=$?
  n=$(grep -c '^  PASS' <<<"$out"); e=$(grep -c '^  PASS' "$ev"); f=$(grep -c '^  FAIL' <<<"$out")
  count_ok "$task $mode" "$rc" "$n" "$e" "$f"; }
ckp "T04 run-checks.sh --regression: exit 0, no FAIL, PASS not below the count at close (118)" same_count T04 --regression docs/tests/T04/evidence/run-checks-regression.txt
ckp "T03 run-checks.sh: exit 0, no FAIL, PASS not below the count at close" same_count T03 "" docs/tests/T03/evidence/run-checks.txt
ckp "count rule accepts equal and higher PASS counts (control)" accepts count_ok ctl 0 118 118 0
ckp "count rule accepts a SKIP turned into PASS (control)" accepts count_ok ctl 0 119 118 0
ckp "count rule rejects a PASS that dropped (control)" rejects count_ok ctl 0 117 118 0
ckp "count rule rejects a FAIL line or a non-zero exit (control)" bash -c "$(declare -f count_ok); ! count_ok c 0 119 118 1 && ! count_ok c 1 119 118 0"

echo "== TC-T04a-31 optional linters on the tree (AC3, C4); SKIP only when the tool is absent"
opt() { local name=$1 tool=$2; shift 2; if command -v "$tool" >/dev/null 2>&1; then ckp "$name clean" "$@"; else skip "$name: $tool not installed"; fi; }
mypy_run() { mypy --strict --python-version 3.10 scripts .claude/hooks; }
sc_run() { local f; mapfile -t f < <(git ls-files '*.sh'); shellcheck "${f[@]}" .ddev/commands/host/quality; }
md_run() { markdownlint-cli2 "**/*.md"; }
opt "ruff check (lint)" ruff ruff check .
opt "ruff format --check" ruff ruff format --check .
opt "mypy --strict scripts and .claude/hooks (py310)" mypy mypy_run
opt "shellcheck on tracked shell scripts" shellcheck sc_run
opt "yamllint on the tree" yamllint yamllint .
opt "markdownlint-cli2" markdownlint-cli2 md_run
if [ -x .tools/pre-commit ]; then ckp "pre-commit run --all-files" .tools/pre-commit run --all-files; else skip "pre-commit: .tools/pre-commit not installed"; fi

echo "== TC-T04a-32 documentation and traceability (C5)"
ckp "scripts/README.md lists quality.sh and the five check scripts" allin scripts/README.md 'quality\.sh' 'check_commit_msg' 'check_branch_name' 'exceptions_report' 'coverage_gate' 'check_assets'
ckp ".ddev/README.md describes the quality command and that it works from T05" allin .ddev/README.md 'quality' 'T05'
ckp "CLAUDE.md commands table lists scripts/quality.sh" gF CLAUDE.md 'scripts/quality.sh'
trow() { grep -E "^\| *$1 " docs/TRACEABILITY.md | grep -q 'T04a'; }
ckp "TRACEABILITY R-12 row names T04a" trow R-12
ckp "TRACEABILITY NFR-18 row names T04a (coverage thresholds)" trow NFR-18

echo "== TC-T04a-33 simulation-only, no secrets, .env.example unchanged (C6, SIM)"
BR='zerodha|kite ?connect|\bkite\b|upstox|angel ?(one|broking)|groww|fyers|5paisa|dhanhq|alice ?blue|interactive ?brokers|alpaca|icici ?direct|smartapi|kite\.trade'
t4files() { git ls-files -co --exclude-standard -- docs/standards scripts quality .ddev ruff.toml mypy.ini .yamllint.yaml "$MD_CFG" .shellcheckrc "$PC" apps/drupal/phpcs.xml.dist apps/drupal/phpstan.neon.dist apps/web/eslint.config.mjs tsconfig.base.json .prettierrc.json "$T/test-cases.md"; }
nobr() { local f; mapfile -t f < <(t4files); [ ${#f[@]} -ge 10 ] && ! grep -niE "$BR" "${f[@]}"; }
ckp "no broker vendor names or trading hostnames in the T04a files" nobr
nosec() { local f; mapfile -t f < <(t4files); [ ${#f[@]} -ge 10 ] && ! grep -nE 'sk-ant-[A-Za-z0-9]|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20}|xox[bp]-' "${f[@]}"; }
ckp "no secret patterns in the T04a files" nosec
envsame() { local first base   # review finding 6: base = parent of the first T04a commit, not local main
  first=$(git log --format=%H --grep='^T04a: ' --reverse | head -1); [ -n "$first" ] || { echo "no T04a commit yet"; return 1; }
  base=$(git rev-parse "$first^") || return 1; echo "base $base"
  # T06: variable lines only (comments may change, T06 plan KD-9); names and values must be identical
  diff <(git show "$base:.env.example" | grep -E '^[A-Za-z_][A-Za-z0-9_]*=') <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' .env.example); }
ckp ".env.example variable lines unchanged since the parent of the first T04a commit (no new variables; comments may change)" envsame
ckp "check-names.sh clean" scripts/check-names.sh

echo "== TC-T04a-34 process: plan approved, tests designed before authoring, review done (C1, C2) [snapshot]"
cka "plan.md status Approved" g docs/tasks/T04a/plan.md '^\| Status \| Approved'
first_commit() { git log --diff-filter=A --format=%H --reverse -- "$1" 2>/dev/null | head -1; }
order_ok() { local s c m f; s=$(first_commit "$T"/run-checks.sh); c=$(first_commit "$T"/test-cases.md)
  [ -n "$s" ] && [ -n "$c" ] || { echo "design not committed"; return 1; }
  for f in "$SA" "$RC" scripts/quality.sh scripts/check_commit_msg.py; do m=$(first_commit "$f"); [ -z "$m" ] && continue
    if ! { [ "$s" != "$m" ] && [ "$c" != "$m" ] && git merge-base --is-ancestor "$s" "$m" && git merge-base --is-ancestor "$c" "$m"; }; then
      echo "order violated for $f"; return 1
    fi
  done; }
cka "run-checks.sh and test-cases.md committed before the standards, checklist and scripts (git order)" order_ok
review_ok() { [ -s docs/tasks/T04a/review.md ] && grep -qiE 'approved' docs/tasks/T04a/review.md; }
cka "technical-architect review exists and is Approved" review_ok
design_msg() { git log --format=%s -- "$T"/run-checks.sh | tail -1 | grep -qE '^T04a:'; }
cka "design commit message starts with T04a:" design_msg

echo "== TC-T04a-35 no component scaffolds yet (plan non-goal; makes the SKIP rule real) [snapshot]"
absent() { [ ! -e "$1" ]; }
for m in services/engine/pyproject.toml apps/drupal/composer.json apps/web/package.json .ddev/config.yaml; do
  cka "$m is absent (arrives in T05, T13 or T21)" absent "$m"
done

# ----- owner-run and deferred cases (never counted as pass) -----
echo "== TC-T04a-36 to 47 owner-run (run: $0 --owner)"
blk "TC-T04a-36 bootstrap-dev.sh in a clean copy installs pre-commit and both hook types; versions captured (network)"
blk "TC-T04a-37 pre-commit run --all-files: zero violations on the clean tree (network)"
blk "TC-T04a-38 scripts/quality.sh exits 0 on the clean tree with component steps SKIP (network)"
blk "TC-T04a-39 to 45 rejection demos with controls: untyped Python, ruff, long Markdown, shellcheck, YAML, hadolint, Spectral"
blk "TC-T04a-46 bad commit message refused by the installed hook; TC-T04a-47 bad branch name fails quality.sh"
echo "== TC-T04a-48 to 52 deferred or manual"
if [ -f .ddev/config.yaml ] && command -v ddev >/dev/null 2>&1; then
  ckp "TC-48 ddev quality exits 0 on a clean tree" ddev quality
else blk "TC-T04a-48 ddev quality (needs .ddev/config.yaml from T05 and DDEV)"; fi
blk "TC-T04a-49 bad PHP style rejected by phpcs and PHPStan (needs T05 Composer tools; custom modules from T09)"
blk "TC-T04a-50 ESLint error, tsc --noEmit failure, Prettier failure (needs the T21 scaffold)"
blk "TC-T04a-51 CI coverage drop, CI branch-name check, real Cobertura attribute names (needs T08, T09, T13, T21)"
blk "TC-T04a-52 manual review of ten standards rules against the checklist (tester, evidence manual-review.md)"
echo "== TC-T04a-53 to 56 owner-run real-tool checks of the D-4 addendum 'verify' rows (OQ-T04a-6)"
blk "TC-T04a-53 coverage.py honours '# pragma: no cover  # T13: reason' (owner-run, pip install coverage)"
blk "TC-T04a-54 hadolint honours '# hadolint ignore=DL3008 # T06: reason' (owner-run)"
blk "TC-T04a-55 markdownlint honours the separate-comment ticket form (owner-run)"
blk "TC-T04a-56 yamllint per-rule ignore: path with a ticket comment works; the inline ticket form is silently ignored (owner-run)"
echo "== TC-T04a-57 to 58 deferred real-tool checks of the addendum"
blk "TC-T04a-57 TypeScript '// @ts-expect-error T21: reason' suppresses the error (deferred to T21)"
blk "TC-T04a-58 phpcs '// phpcs:ignore <sniff> -- T09: reason' suppresses the sniff (deferred to T05 or T09)"

# =====================================================================================================
else   # ---------- --owner mode ----------
echo "== Owner-run cases TC-T04a-36 to 47. Needs network the first time (pre-commit downloads hook environments)."
OD=$WORK/clone; mkdir -p "$OD"
git ls-files -co --exclude-standard -z | tar --null -T - -cf - 2>/dev/null | tar -x -C "$OD"
git -C "$OD" init -q -b main && git -C "$OD" config user.email o@example.invalid && git -C "$OD" config user.name owner && git -C "$OD" config commit.gpgsign false
git -C "$OD" add -A && git -C "$OD" commit -q -m "T04a: owner clone"
PCB=$OD/.tools/pre-commit
mkdir -p "$ROOT/$T/evidence"
echo "== TC-T04a-36 bootstrap in a clean copy (C7)"
ob() { (cd "$OD" && scripts/bootstrap-dev.sh) 2>&1; }
ckp "scripts/bootstrap-dev.sh succeeds in a clean copy" ob
ckp "pre-commit installed ($("$PCB" --version 2>&1))" test -x "$PCB"
ckp ".git/hooks/pre-commit exists" test -f "$OD/.git/hooks/pre-commit"
ckp ".git/hooks/commit-msg exists (commit-msg hook type installed)" test -f "$OD/.git/hooks/commit-msg"
echo "  tool revisions captured (C7):"; grep -E '^\s+rev:|spectral-cli@' "$OD/.pre-commit-config.yaml" | sed 's/^/    /'
echo "== TC-T04a-37 baseline clean"
opc() { (cd "$OD" && .tools/pre-commit run --all-files); }
ckp "pre-commit run --all-files exits 0" opc
echo "== TC-T04a-38 quality.sh on the clean tree"
oq() { (cd "$OD" && git checkout -q -b task/T04a-owner-demo && scripts/quality.sh); }
ckp "scripts/quality.sh exits 0" oq
oqs() { local n; n=$(cd "$OD" && scripts/quality.sh 2>&1 | grep -cE 'SKIP.*(engine|drupal|web)'); [ "$n" -ge 3 ]; }
ckp "three component SKIP lines present (engine, drupal, web)" oqs
# demo TC FILE BAD GOOD [x]: the bad file is refused by the hooks, the same-named control is accepted
demo() { local tc=$1 file=$2 bad=$3 good=$4 x=${5:-} brc grc
  put "$OD/$file" "$bad"; [ -n "$x" ] && chmod +x "$OD/$file"; git -C "$OD" add "$file"
  (cd "$OD" && .tools/pre-commit run --files "$file") >"$ROOT/$T/evidence/$tc-rejected.txt" 2>&1; brc=$?
  put "$OD/$file" "$good"; [ -n "$x" ] && chmod +x "$OD/$file"; git -C "$OD" add "$file"
  (cd "$OD" && .tools/pre-commit run --files "$file") >"$ROOT/$T/evidence/$tc-control.txt" 2>&1; grc=$?
  git -C "$OD" rm -q -f --cached "$file"; rm -f "$OD/$file"
  [ "$brc" -ne 0 ] && [ "$grc" -eq 0 ] || { echo "bad rc=$brc (want non-zero), control rc=$grc (want 0)"; return 1; }; }
echo "== TC-T04a-39 untyped Python rejected by mypy --strict (control: typed)"
ckp "scripts/zz_demo.py untyped refused; typed twin accepted" demo TC-T04a-39 scripts/zz_demo.py $'def add(a, b):\n    return a + b' $'def add(a: int, b: int) -> int:\n    """Add."""\n    return a + b'
echo "== TC-T04a-40 ruff lint rejection"
ckp "unused import refused by ruff; clean twin accepted" demo TC-T04a-40 scripts/zz_ruff.py $'import os' $'"""Doc."""'
echo "== TC-T04a-41 long Markdown line"
LONG=$(printf 'word %.0s' $(seq 1 40)); WRAPPED=$(printf 'word %.0s' $(seq 1 10); echo; printf 'word %.0s' $(seq 1 10))
ckp "200-character prose line refused by markdownlint; wrapped twin accepted" demo TC-T04a-41 docs/zz_demo.md "$(printf '# Demo\n\n%s' "$LONG")" "$(printf '# Demo\n\n%s' "$WRAPPED")"
echo "== TC-T04a-42 shellcheck"
ckp "unterminated string refused by shellcheck; clean twin accepted" demo TC-T04a-42 scripts/zz_demo.sh $'#!/usr/bin/env bash\necho "unterminated' $'#!/usr/bin/env bash\necho ok' x
echo "== TC-T04a-43 YAML"
ckp "duplicate key refused by yamllint; clean twin accepted" demo TC-T04a-43 docs/zz_demo.yaml $'---\na: 1\na: 2' $'---\na: 1'
echo "== TC-T04a-44 hadolint"
ckp "untagged base image refused by hadolint; tagged twin accepted" demo TC-T04a-44 zz/Dockerfile $'FROM ubuntu\nRUN cd /tmp && ls' $'FROM alpine:3.20\nCMD ["true"]'
echo "== TC-T04a-45 Spectral"
sp() { local f=docs/architecture/openapi.yaml good bad; good=$(cat "$OD/$f"); bad=$(sed '0,/^info:/s//infox:/' "$OD/$f"); demo TC-T04a-45 "$f" "$bad" "$good"; }
ckp "OpenAPI with 'info' renamed refused by Spectral; the original accepted" sp
echo "== TC-T04a-46 bad commit message through the installed hook"
oc() { cd "$OD" || return 1; git checkout -q -b task/T04a-owner-commit; local n0 n1; n0=$(git rev-list --count HEAD)
  if git commit --allow-empty -q -m "bad message" 2>"$ROOT/$T/evidence/TC-T04a-46-rejected.txt"; then return 1; fi
  n1=$(git rev-list --count HEAD); [ "$n0" = "$n1" ] || return 1
  git commit --allow-empty -q -m "T04a: owner demo"; }
ckp "'bad message' refused (no commit created); 'T04a: owner demo' accepted" oc
echo "== TC-T04a-47 bad branch name through quality.sh"
ob2() { cd "$OD" || return 1; git checkout -q -b feature/bad; local ev="$ROOT/$T/evidence/TC-T04a-47-rejected.txt"
  scripts/quality.sh >"$ev" 2>&1; local rc=$?; [ "$rc" -ne 0 ] && grep -qiE 'FAIL.*branch' "$ev"; }
ckp "branch feature/bad: quality.sh exits non-zero with a FAIL on the branch step" ob2

# ----- real-tool checks of the D-4 addendum rows marked 'verify' (OQ-T04a-6) -----
# hookrun FILE CONTENT: write FILE in the clone, run every hook on it, leave the output in HOUT and the status in HRC
hookrun() { put "$OD/$1" "$2"; git -C "$OD" add "$1"; HOUT=$(cd "$OD" && .tools/pre-commit run --files "$1" 2>&1); HRC=$?
  git -C "$OD" rm -q -f --cached "$1"; rm -f "$OD/$1"; }
echo "== TC-T04a-53 coverage.py pragma form"
cov() { local v=$WORK/venv; python3 -m venv "$v" && "$v/bin/pip" install -q coverage || return 1
  local d=$WORK/cov; mkdir -p "$d"; cd "$d" || return 1
  printf 'def f(a):\n    if a:\n        return 1\n    if a < 0:  # pragma: no cover  # T13: reason\n        return 2\n    return 0\n' >x.py
  printf 'def f(a):\n    if a:\n        return 1\n    if a < 0:\n        return 2\n    return 0\n' >y.py
  printf 'import x, y\nx.f(1); x.f(0); y.f(1); y.f(0)\n' >t.py
  if ! { "$v/bin/coverage" run t.py && "$v/bin/coverage" report -m --include=x.py --fail-under=100 >"$ROOT/$T/evidence/TC-T04a-53-pragma.txt" 2>&1; }; then
    echo "pragma form did not exclude the line"; return 1
  fi
  "$v/bin/coverage" report -m --include=y.py --fail-under=100 >"$ROOT/$T/evidence/TC-T04a-53-control.txt" 2>&1 && { echo "control without pragma reached 100"; return 1; }; return 0; }
ckp "x.py with the ticketed pragma reaches 100 percent; the same code without it does not" cov
echo "== TC-T04a-54 hadolint ignore with a ticket comment"
hl() { hookrun zz/Dockerfile $'FROM alpine:3.20\n# hadolint ignore=DL3018 # T06: reason\nRUN apk add curl'; local a=$HOUT
  hookrun zz/Dockerfile $'FROM alpine:3.20\nRUN apk add curl'; local b=$HOUT
  printf '%s\n' "$a" >"$ROOT/$T/evidence/TC-T04a-54-ignored.txt"; printf '%s\n' "$b" >"$ROOT/$T/evidence/TC-T04a-54-control.txt"
  ! grep -q DL3018 <<<"$a" && grep -q DL3018 <<<"$b"; }
ckp "DL3018 reported without the pragma, absent with '# hadolint ignore=DL3018 # T06: reason'" hl
echo "== TC-T04a-55 markdownlint separate-comment ticket form"
LONGP=$(printf 'word %.0s' $(seq 1 40))
ml() { hookrun docs/zz_ml.md "$(printf '# T\n\n<!-- markdownlint-disable-next-line MD013 --> <!-- T32: reason -->\n%s\n' "$LONGP")"; local a=$HOUT ra=$HRC
  hookrun docs/zz_ml.md "$(printf '# T\n\n%s\n' "$LONGP")"; local b=$HOUT rb=$HRC
  printf '%s\n' "$a" >"$ROOT/$T/evidence/TC-T04a-55-ignored.txt"; printf '%s\n' "$b" >"$ROOT/$T/evidence/TC-T04a-55-control.txt"
  [ "$ra" -eq 0 ] && [ "$rb" -ne 0 ]; }
ckp "long line passes with the disable-next-line plus ticket comment; fails without" ml
echo "== TC-T04a-56 yamllint ignore: path list and the inline ticket form"
yl() { local cfg=$OD/.yamllint.yaml; cp "$cfg" "$WORK/yamllint.orig"
  printf -- '---\nextends: default\nrules:\n  line-length:\n    max: 40\n    ignore:\n      - docs/zz_ignored.yaml  # T32: reason\n' >"$cfg"
  local long='---\nkey: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
  hookrun docs/zz_ignored.yaml "$(printf '%b' "$long")"; local a=$HRC; printf '%s\n' "$HOUT" >"$ROOT/$T/evidence/TC-T04a-56-ignored.txt"
  hookrun docs/zz_other.yaml "$(printf '%b' "$long")"; local b=$HRC; printf '%s\n' "$HOUT" >"$ROOT/$T/evidence/TC-T04a-56-control.txt"
  hookrun docs/zz_inline.yaml "$(printf '%b # yamllint disable-line rule:line-length # T32: x' "$long" | sed 's/"$/"/')"; local c=$HRC; printf '%s\n' "$HOUT" >"$ROOT/$T/evidence/TC-T04a-56-inline.txt"
  cp "$WORK/yamllint.orig" "$cfg"
  [ "$a" -eq 0 ] && [ "$b" -ne 0 ] && [ "$c" -ne 0 ]; }
ckp "ignored path passes; other path fails; inline directive with trailing ticket text is silently ignored (still fails)" yl
fi

echo
if [ "$MODE" = reg ]; then
  echo "NOTE: --regression mode: $excluded at-close (snapshot) checks excluded because they are true only at the close of T04a; $ran invariant checks executed; owner-run and deferred cases are not part of the regression set."
else
  echo "NOTE: mode $MODE: $ran checks executed, $skipped SKIP (optional tools, listed above), $blocked BLOCKED (owner-run or deferred, listed above)."
fi
if [ $fail -eq 0 ]; then echo "RESULT: ALL EXECUTED CHECKS PASSED ($blocked blocked)"; else echo "RESULT: ONE OR MORE CHECKS FAILED"; fi
exit $fail
