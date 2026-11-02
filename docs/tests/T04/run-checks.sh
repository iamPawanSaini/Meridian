#!/usr/bin/env bash
# Automated checks for T04 (master test plan, docs-only). Designed from the acceptance criteria in
# docs/TASKS.md, the approved plan docs/tasks/T04/plan.md and the decisions in
# docs/tasks/T04/decision-t04-test-strategy.md, NOT from the finished documents.
#
# Usage:  docs/tests/T04/run-checks.sh               all checks (task close)
#         docs/tests/T04/run-checks.sh --regression  invariant checks only (CI PR set, decision D-5)
# Exit status is non-zero if any executed check fails. A missing document makes every dependent
# check FAIL; nothing passes vacuously. SKIP is used only for optional tools (pre-commit, markdownlint).
#
# Tags (decision D-5). Every check is one of:
#   ckp  = invariant: must hold for the rest of the project; runs in both modes.
#   cka  = snapshot : true only at the close of T04 (git order, comparison with a named branch,
#                     exact counts, policy text pending owner confirmation); skipped by --regression,
#                     and the skipped count is printed. Retagging ckp -> cka needs a Change log entry in
#                     test-cases.md naming the later task that changed the content.
# (The task owner calls these "permanent" and "at-close"; D-5 calls them invariant and snapshot.)
#
# Layout assumed (from the plan, and recorded in test-cases.md): docs/tests/master-test-plan.md with
# '#' headings for: Test levels (one sub-heading per level), Tools per component, Test layout,
# Environments, Entry and exit criteria, Defect severity, Regression suite, Test data strategy,
# Reconciliation, Conventions, and a defect-workflow section. docs/TRACEABILITY.md has a heading
# "Planned tests" followed by a 7-column table (ID, Parent R, Verifying task, Level(s), Planned test,
# Planned case ID or pattern, Status). Helpers: check_trace.py, check_defects.py, selftest_trace.py.
# shellcheck disable=SC2329 # T04a: functions are invoked indirectly through ck/py/check ("$@")
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
T=docs/tests/T04

REG=0
case "${1:-}" in
  "") ;;
  --regression) REG=1 ;;
  *) echo "usage: $0 [--regression]" >&2; exit 2 ;;
esac

fail=0; excluded=0; ran=0
pass() { printf '  PASS  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=1; }
# ckp DESC CMD...: invariant check. cka DESC CMD...: snapshot check (not run with --regression).
ckp() { local d=$1; shift; ran=$((ran+1)); if "$@" >/dev/null 2>&1; then pass "$d"; else bad "$d"; fi; }
cka() { local d=$1; shift
  if [ $REG -eq 1 ]; then excluded=$((excluded+1)); return 0; fi
  ran=$((ran+1)); if "$@" >/dev/null 2>&1; then pass "[at-close] $d"; else bad "[at-close] $d"; fi; }
# pyp DESC CMD...: invariant python check; prints the checker's own lines on failure.
pyp() { local d=$1; shift; ran=$((ran+1)); local out; out=$("$@" 2>&1); local rc=$?
  if [ $rc -eq 0 ]; then pass "$d"; else bad "$d"; printf '%s\n' "$out" | head -8 | sed 's/^/        /'; fi; }
pya() { local d=$1; shift
  if [ $REG -eq 1 ]; then excluded=$((excluded+1)); return 0; fi
  ran=$((ran+1)); local out; out=$("$@" 2>&1); local rc=$?
  if [ $rc -eq 0 ]; then pass "[at-close] $d"; else bad "[at-close] $d"; printf '%s\n' "$out" | head -8 | sed 's/^/        /'; fi; }

MP=docs/tests/master-test-plan.md
DF=docs/tests/defects.md
TP=docs/templates/defect.md
SA=docs/architecture/solution-architecture.md
TR=docs/TRACEABILITY.md
RD=docs/tests/README.md
BASE=task/T03-technical-design

# g FILE ERE: file non-empty and contains pattern (case-insensitive)
g() { [ -s "$1" ] && grep -qiE -- "$2" "$1"; }
# hd FILE ERE: a Markdown heading matching the pattern exists
hd() { [ -s "$1" ] && grep -qiE -- "^#+ .*($2)" "$1"; }
# AWKSEC: section from the matching heading to the next heading of the same or higher level
# shellcheck disable=SC2016 # T04a: awk program, deliberately single-quoted
AWKSEC='/^#+ /{match($0,/^#+/); l=RLENGTH; if(on&&l<=lv)on=0; if(!on && tolower($0) ~ tolower(re)){on=1;lv=l}} on'
sec()  { [ -s "$1" ] || return 1; awk -v re="$2" "$AWKSEC" "$1"; }
secs() { awk -v re="$1" "$AWKSEC"; }          # same, reading stdin (for sub-sections)
# gs FILE HEADING_RE ERE: pattern occurs inside the named section
gs() { sec "$1" "$2" | grep -qiE -- "$3"; }
# gsall FILE HEADING_RE ERE...: every pattern occurs inside the section (and the section is non-empty)
gsall() { local f=$1 h=$2; shift 2; local s; s=$(sec "$f" "$h"); [ -n "$s" ] || return 1
  local p; for p in "$@"; do printf '%s\n' "$s" | grep -qiE -- "$p" || return 1; done; }
# allin FILE ERE...: every pattern occurs somewhere in the file
allin() { local f=$1; shift; [ -s "$f" ] || return 1; local p; for p in "$@"; do grep -qiE -- "$p" "$f" || return 1; done; }
# level_ok HEADING_RE: the sub-heading exists inside "Test levels", names owning tasks (Tnn) and a pass rule
level_ok() { local body; body=$(sec "$MP" 'test levels' | secs "^#+ .*($1)"); [ -n "$body" ] || return 1
  [ ${#body} -ge 200 ] || return 1
  printf '%s\n' "$body" | grep -qE 'T[0-9]+' || return 1
  printf '%s\n' "$body" | grep -qiE 'pass' ; }
# rowhas LABEL_ERE TOOL_ERE...: in the tools section, a table row whose first cell matches the label names every tool
rowhas() { local lab=$1; shift; local row; row=$(sec "$MP" 'tools' | grep -iE "^\| *[^|]*($lab)" | head -3); [ -n "$row" ] || return 1
  local t; for t in "$@"; do printf '%s\n' "$row" | grep -qiE -- "$t" || return 1; done; }
# prow ID: the planned-tests row for an FR/NFR (the only TRACEABILITY rows that start with FR- or NFR-)
prow()     { grep -E "^\| *$1 *\|" "$TR" | head -1; }
prow_col() { local l; l=$(prow "$1"); [ -n "$l" ] || return 1; printf '%s\n' "$l" | awk -F'|' -v c="$2" '{print tolower($c)}' | grep -qiE -- "$3"; }
# col numbers after splitting on '|': 2 ID, 3 parent, 4 task, 5 level, 6 planned test, 7 case, 8 status
no_markers() { [ -s "$1" ] && ! grep -nE '\b(TODO|TBD|FIXME|XXX)\b' "$1"; }
links_resolve() { python3 -I - "$@" <<'PY'
import re, sys, os
bad = []
for f in sys.argv[1:]:
    if not os.path.isfile(f): bad.append(f + " missing"); continue
    for m in re.finditer(r"\]\(([^)#\s]+)(#[^)]*)?\)", open(f).read()):
        t = m.group(1)
        if re.match(r"[a-z]+:", t): continue
        if not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(f), t))): bad.append(f"{f}: {t}")
print(bad[:5]); sys.exit(1 if bad else 0)
PY
}
# order_ok: run-checks.sh and test-cases.md were committed (their first commit) strictly before master-test-plan.md
first_commit() { git log --diff-filter=A --format=%H --reverse -- "$1" 2>/dev/null | head -1; }
order_ok() {
  local s c m
  s=$(first_commit "$T/run-checks.sh"); c=$(first_commit "$T/test-cases.md")
  [ -n "$s" ] && [ -n "$c" ] || return 1               # design must be committed
  m=$(first_commit "$MP")
  [ -z "$m" ] && return 0                              # plan not committed yet: order holds
  [ "$s" != "$m" ] && [ "$c" != "$m" ] && git merge-base --is-ancestor "$s" "$m" && git merge-base --is-ancestor "$c" "$m"
}
changelog_ok() {   # if run-checks.sh changed after its first commit, test-cases.md needs a Change log row
  local n; n=$(git log --format=%H -- "$T/run-checks.sh" | wc -l)
  [ "$n" -ge 1 ] || return 1
  [ "$n" -le 1 ] && return 0
  sec "$T/test-cases.md" 'change log' | grep -E '^\|' | grep -vE '^\|[ :|-]+\|?[ ]*$' | tail -n +2 | grep -q .
}
design_msg_ok() { git log --format=%s -- "$T/run-checks.sh" | tail -1 | grep -qE '^T04:'; }

echo "== TC-T04-01 master-test-plan.md: eight test levels, each with owning tasks and a pass rule"
ckp "master-test-plan.md exists and is non-empty" test -s "$MP"
ckp "section 'Test levels' exists" hd "$MP" 'test levels'
for lv in 'unit' 'integration' 'contract' 'end-to-end|e2e' 'security' 'performance' 'data reconciliation' 'manual simulation'; do
  ckp "level '$lv': sub-heading with owning tasks (Tnn) and a pass rule" level_ok "$lv"
done

echo "== TC-T04-02 required top-level sections"
for h in 'tools' 'layout' 'environments' 'entry' 'exit' 'severity' 'regression' 'test data' 'reconciliation' 'conventions'; do
  ckp "heading for '$h'" hd "$MP" "$h"
done
ckp "heading for the defect workflow (or a pointer section)" hd "$MP" 'defect'

echo "== TC-T04-03 tools per component (AC2): each component row names its tools"
tools_table() { sec "$MP" 'tools' | grep -qE '^\|'; }
ckp "tools section has a table" tools_table
ckp "Engine row: pytest, pytest-cov, pytest-socket, respx" rowhas 'engine' 'pytest' 'pytest-cov' 'pytest-socket' 'respx'
ckp "Drupal row: PHPUnit with Unit, Kernel and Functional" rowhas 'drupal' 'phpunit' 'unit' 'kernel' 'functional'
ckp "Next.js row: Vitest, Playwright, axe (@axe-core/playwright)" rowhas 'next' 'vitest' 'playwright' 'axe'
ckp "Contract row: Schemathesis, openapi-core, Spectral" rowhas 'contract' 'schemathesis' 'openapi-core' 'spectral'
ckp "Security row: gitleaks, pip-audit, composer audit, npm audit, image scan, static broker check" rowhas 'security' 'gitleaks' 'pip-audit' 'composer audit' 'npm audit' 'image' 'broker'
ckp "Performance row: web-vitals and the Python timing harness" rowhas 'performance' 'web-vitals' 'harness|perf_counter'
ckp "plan says versions are pinned in T04a, tools named by purpose only" gs "$MP" 'tools' 'T04a'

echo "== TC-T04-04 tool decisions D-2, D-3, D-4 recorded"
ckp "contract: Schemathesis against DDEV; openapi-core in engine tests; T11 extends openapi.yaml" gsall "$MP" 'tools' 'schemathesis.*ddev|ddev.*schemathesis' 'openapi-core' 'T11.*openapi\.yaml|openapi\.yaml.*T11'
ckp "Dredd and Prism are not the contract tool" gs "$MP" 'tools' '(dredd|prism)[^|]{0,80}(reject|not adopt|not used)|(reject|not adopt)[^|]{0,80}(dredd|prism)'
ckp "performance: nearest-rank percentile, raw samples kept, k6/Locust not adopted" gsall "$MP" 'tools|performance' 'nearest.rank' 'raw samples?' '(k6|locust)[^|]{0,80}(not adopt|reject)|(not adopt|reject)[^|]{0,80}(k6|locust)'
ckp "network blocking: pytest-socket disable-socket and a no-network container; vcrpy rejected" gsall "$MP" 'tools|test data' 'disable-socket' '(network none|no-network|no network)' 'vcrpy[^|]{0,80}(reject|not adopt)|(reject|not adopt)[^|]{0,80}vcrpy'
ckp "market data mocked at the provider boundary (T15 interface)" g "$MP" 'provider (boundary|interface)'

echo "== TC-T04-05 test layout convention per component"
ckp "layout section lists engine unit, integration, contract and fixtures paths" gsall "$MP" 'layout' 'services/engine/tests/unit' 'services/engine/tests/integration' 'services/engine/tests/contract' 'tests/fixtures'
ckp "layout lists Drupal Unit, Kernel, Functional under meridian_*/tests/src" gsall "$MP" 'layout' 'meridian_\*/tests/src' 'Unit' 'Kernel' 'Functional'
ckp "layout lists Next.js unit tests next to source and apps/web/e2e" gsall "$MP" 'layout' 'apps/web/e2e' 'next to'
ckp "layout lists docs tasks docs/tests/Txx/run-checks.sh" gs "$MP" 'layout' 'docs/tests/Txx/run-checks\.sh'

echo "== TC-T04-06 environments and level-by-environment matrix"
ckp "four environments named: sandbox, DDEV, CI (GitHub Actions), deployed dev (Pantheon, Vercel)" gsall "$MP" 'environments' 'sandbox' 'ddev' 'github actions' 'pantheon' 'vercel'
ckp "sandbox has no network; CI has no live market data or LLM" gsall "$MP" 'environments' 'no network' 'no live (market data|data)|without live' '(llm|claude)'
envmatrix_ok() { local s; s=$(sec "$MP" 'environments' | grep '^|'); [ -n "$s" ] || return 1
  local l; for l in 'unit' 'integration' 'contract' 'end-to-end|e2e' 'security' 'performance' 'reconciliation' 'manual'; do
    printf '%s\n' "$s" | grep -qiE "^\| *[^|]*($l)" || return 1; done; }
ckp "matrix has a table row for each of the 8 levels" envmatrix_ok

echo "== TC-T04-07 entry and exit criteria (AC1)"
ckp "entry criteria cover per task and per milestone" gsall "$MP" 'entry' 'task' 'milestone'
ckp "entry criteria require an approved plan and committed test design" gs "$MP" 'entry' 'plan'
ckp "exit: all cases Pass, or Blocked with recorded owner acceptance; no open Critical or High defect" gsall "$MP" 'exit' 'pass' 'blocked' 'owner' 'critical' 'high' 'defect'
ckp "exit: evidence stored for every case" gs "$MP" 'exit' 'evidence'

echo "== TC-T04-08 defect severity scale: one source, identical levels everywhere"
ckp "master plan severity table lists Critical, High, Medium, Low (in order), defects.md links to it" python3 -I $T/check_defects.py severity
pyp "each severity has a meaning of at least 15 characters in the master plan" python3 -I $T/check_defects.py meanings
ckp "Critical includes live-order capability / wrong financial result / security breach" gs "$MP" 'severity' 'critical[^|]*\|[^|]*(live|order)'

echo "== TC-T04-09 regression suite and CI (AC3)"
ckp "regression section names ci.yml" gs "$MP" 'regression' 'ci\.yml'
ckp "PR set: unit, Kernel, Vitest, contract against fixtures, static broker check, docs checks" gsall "$MP" 'regression' 'pr set|pull request' 'unit' 'kernel' 'vitest' 'fixtures' 'broker' 'docs'
ckp "heavier set: Functional, Playwright, ddev e2e with a trigger" gsall "$MP" 'regression' 'functional' 'playwright' 'ddev e2e' 'nightly|schedule|label|merge to main|push to main|manual|dispatch'
ckp "T08 implements the CI jobs" gs "$MP" 'regression' 'T08'
ckp "docs run-checks scripts join the PR set via --regression with invariant/snapshot tags" gsall "$MP" 'regression|conventions' '--regression' 'invariant' 'snapshot'
ckp "excluded snapshot checks are counted and printed; invariants still fail the job" gs "$MP" 'regression|conventions' 'excluded|skipped.*count|count.*excluded'

echo "== TC-T04-10 test data strategy: four kinds plus rules (AC4)"
ckp "fixtures: owner, location and refresh rule" gsall "$MP" 'test data' 'fixtures' 'owner' 'refresh'
ckp "recorded market data: committed JSON/CSV, an NSE holiday and a no-new-candle date (FR-23)" gsall "$MP" 'test data' 'recorded market data' 'json|csv' 'holiday' 'no.new.candle' 'FR-23'
ckp "fake LLM responses: one per failure type (FR-06) and the prompt-injection set (FR-07)" gsall "$MP" 'test data' 'fake llm' 'FR-06' 'FR-07' 'injection'
ckp "failure types named: malformed, empty, timeout, API error, schema violation" gsall "$MP" 'test data' 'malformed' 'empty' 'timeout' 'api error' 'schema'
ckp "seeded Drupal content: 5,000 records for NFR-03/05, T11, T25, T26" gsall "$MP" 'test data' 'seeded drupal' '5,?000' 'NFR-03' 'NFR-05'
ckp "golden parity file (T13)" gsall "$MP" 'test data' 'golden' 'T13'
ckp "rules: no real secrets, no live network in CI, deterministic data" gsall "$MP" 'test data' 'no real secrets?' 'no live network' 'deterministic'

echo "== TC-T04-11 reconciliation method and tolerances"
ckp "FR-14 zero differences; FR-18 0.01 rupee and 0.01 percentage points" gsall "$MP" 'reconciliation' 'FR-14' 'FR-18' '0\.01' 'percentage point|pp'
ckp "hops named: Postgres, Drupal, UI; used by T27 and T31" gsall "$MP" 'reconciliation' 'postgres' 'drupal' 'UI|dashboard' 'T27' 'T31'

echo "== TC-T04-12 conventions codified from T00 to T03"
ckp "statuses Pass, Fail, Blocked, Not run; Blocked means missing precondition or tool, not a product fault" gsall "$MP" 'conventions' 'pass' 'fail' 'blocked' 'not run' 'precondition|tool'
ckp "owner-run cases: exact command, expected output, evidence path, tool version" gsall "$MP" 'conventions' 'owner-run' 'tool version|version'
ckp "main-session-executed cases: 'Executed by' names who ran it" gsall "$MP" 'conventions' 'main.session' 'executed by'
ckp "evidence naming: TC-Txx-nn.txt, run-checks.txt, -static and -spotcheck suffixes" gsall "$MP" 'conventions' 'TC-Txx-nn\.txt' 'run-checks\.txt' '-static' '-spotcheck'
ckp "run-checks.sh style: no vacuous pass, non-zero exit, SKIP only for optional tools listed in the report" gsall "$MP" 'conventions' 'vacuous' 'non-zero' 'skip' 'optional'
ckp "script defect Change log; a check may never be loosened to hide a content gap" gsall "$MP" 'conventions' 'change log' 'loosen'
ckp "live-API cases (T17 real-LLM smoke test) are manual, marked and never in CI" gsall "$MP" 'conventions' 'T17' 'manual' 'never in ci|not in ci|never run in ci'
ckp "Blocked-at-close table: case, criterion, reason, owner who accepted, date, owner message reference" gsall "$MP" 'conventions' 'blocked at close' 'owner' 'reference|message'
ckp "independence: execution not in the authoring context; report states who executed" gsall "$MP" 'conventions' 'independen|authoring context|separate' 'executed by'

echo "== TC-T04-13 defect workflow in defects.md and the template (AC6)"
pyp "all 8 workflow states in order in template Status line, in defects.md and in the master plan" python3 -I $T/check_defects.py states
pyp "who moves each state; triage SLA per severity; retest by tester with evidence; Won't fix needs solution-architect; defects vs review findings" python3 -I $T/check_defects.py workflow
pyp "existing DEF-001 and DEF-002 entries preserved with a valid workflow state" python3 -I $T/check_defects.py legacy
ckp "template keeps Steps to reproduce, Expected, Actual" allin "$TP" 'steps to reproduce' 'expected' 'actual'

echo "== TC-T04-14 TRACEABILITY planned-tests table: structure and ID set (AC5)"
ckp "solution-architecture.md yields FR-01..FR-30 and NFR-01..NFR-19 (49 IDs)" python3 -I -c "
import re,sys
t=open('$SA').read()
ids=set(re.findall(r'^\| (FR-\d\d|NFR-\d\d) \|',t,re.M))
sys.exit(0 if len(ids)>=49 and {f'FR-{i:02d}' for i in range(1,31)}|{f'NFR-{i:02d}' for i in range(1,20)}<=ids else 1)"
pyp "heading 'Planned tests' followed by a 7-column table (ID, parent, task, level, test, case, status)" python3 -I $T/check_trace.py header
pyp "planned-test IDs exactly equal the FR/NFR IDs in solution-architecture.md; no duplicates" python3 -I $T/check_trace.py ids

echo "== TC-T04-15 planned-tests table: cells and cross-checks against solution-architecture.md"
pyp "no empty or placeholder cell in any of the 49 rows" python3 -I $T/check_trace.py nocells
pyp "parent R equals the R in solution-architecture.md" python3 -I $T/check_trace.py parents
pyp "verifying tasks equal the tasks in solution-architecture.md, same order" python3 -I $T/check_trace.py tasks
pyp "levels come from the controlled vocabulary" python3 -I $T/check_trace.py levels
pyp "case-ID patterns TC-Txx-* name exactly the verifying tasks, one per task" python3 -I $T/check_trace.py patterns
pyp "status is Planned / Partially verified / Verified / Blocked (accepted, re-run in Txx)" python3 -I $T/check_trace.py status
pyp "planned-test description is a sentence, not a stub" python3 -I $T/check_trace.py text

echo "== TC-T04-16 R rows link to their FR/NFR rows; R table intact"
pyp "R table header unchanged and rows R-01..R-12 present" python3 -I $T/check_trace.py rtable
pyp "every R row's Test cases cell links every FR/NFR whose parent it is" python3 -I $T/check_trace.py rlinks

echo "== TC-T04-17 planned-test spot checks on high-risk rows (content, not structure)"
# colall COL ERE ID...: the column of every listed planned-test row matches (col: 5 level, 6 planned test, 7 case)
colall() { local c=$1 re=$2; shift 2; local i; for i; do prow_col "$i" "$c" "$re" || return 1; done; }
fr11_ok() { colall 5 'security' FR-11 && colall 6 'broker|static' FR-11 && colall 7 'tc-t18.*tc-t30.*tc-t33' FR-11; }
ckp "FR-11: security level; broker/static check in planned test; T18, T30, T33 patterns" fr11_ok
ckp "FR-06: planned test names the five failure types" colall 6 'malformed|five|5 ' FR-06
ckp "FR-07: planned test covers each untrusted input field (injection)" colall 6 'injection' FR-07
ckp "FR-14 and FR-18: data reconciliation level" colall 5 'data reconciliation' FR-14 FR-18
ckp "FR-19, FR-20, FR-21: security level" colall 5 'security' FR-19 FR-20 FR-21
ckp "FR-23: planned test uses a holiday fixture" colall 6 'holiday' FR-23
ckp "NFR-03: performance level and LCP in the planned test" colall 5 'performance' NFR-03
ckp "NFR-03: planned test measures LCP (web-vitals)" colall 6 'lcp|web-vitals' NFR-03
ckp "NFR-01, NFR-04, NFR-05, NFR-07: performance level" colall 5 'performance' NFR-01 NFR-04 NFR-05 NFR-07
ckp "NFR-04, NFR-05: p95 in planned test" colall 6 'p95' NFR-04 NFR-05
ckp "NFR-10: security level, gitleaks over full history" colall 5 'security' NFR-10
ckp "NFR-10: planned test names gitleaks" colall 6 'gitleaks' NFR-10
ckp "NFR-11: planned test names dependency audit and image scan" colall 6 'audit|scan' NFR-11
ckp "NFR-12: axe in the planned test" colall 6 'axe' NFR-12
ckp "NFR-12: both themes in the planned test" colall 6 'theme|dark' NFR-12
ckp "NFR-18: coverage tool in the planned test" colall 6 'pytest-cov|coverage' NFR-18
ckp "FR-28 and FR-29: docs check level" colall 5 'docs check' FR-28 FR-29

echo "== TC-T04-18 existing TRACEABILITY columns unchanged against task/T03-technical-design (snapshot)"
pya "R-table header, columns 1 to 5 and the old Test cases / Evidence text (T00/T01 cells) are preserved" python3 -I $T/check_trace.py unchanged --base "$BASE"

echo "== TC-T04-19 checker self-test (rejects each seeded defect)"
pyp "check_trace.py rejects 15 seeded defects, accepts the good miniature" python3 -I $T/selftest_trace.py

echo "== TC-T04-20 docs/tests/README.md points to the master plan"
ckp "README row for master-test-plan.md is a link that resolves" bash -c "grep -qE '\]\(master-test-plan\.md\)' $RD && test -s $MP"
ckp "defects.md and README links resolve" links_resolve "$RD" "$DF"

echo "== TC-T04-21 test design committed before authoring (snapshot)"
cka "run-checks.sh and test-cases.md are committed, and strictly before master-test-plan.md" order_ok
cka "design commit message starts with 'T04:'" design_msg_ok
cka "if run-checks.sh changed after the design commit, test-cases.md has a Change log entry" changelog_ok

echo "== TC-T04-22 check-names.sh passes"
ckp "scripts/check-names.sh exits 0" scripts/check-names.sh
ckp "T04 documents use current names (meridian_engine / meridian-web, not the old placeholders)" g "$MP" 'meridian_engine|meridian-web|meridian_ingest'

echo "== TC-T04-23 simulation only: no broker names or trading domains"
BR='zerodha|kite ?connect|\bkite\b|upstox|angel ?(one|broking)|groww|fyers|5paisa|dhanhq|\bdhan\b|alice ?blue|interactive ?brokers|alpaca|icici ?direct|smartapi|kite\.trade'
nobroker() { [ -s "$MP" ] && [ -s "$TR" ] && [ -s "$DF" ] && ! grep -niE "$BR" "$MP" "$TR" "$DF" "$TP" "$RD" "$T/test-cases.md"; }
ckp "no broker vendor names or trading hostnames in master plan, TRACEABILITY, defects, template, README, test-cases" nobroker
ckp "master plan states FR-11 static broker check without naming a vendor, simulation-only" gs "$MP" 'security|regression' 'FR-11'
ckp "no network URL to a trading host anywhere in docs/tests/T04 scripts" bash -c "! grep -niE 'https?://[a-z0-9.-]*(zerodha|kite|upstox|angelone|groww|fyers)' $T/*.py $T/run-checks.sh"

echo "== TC-T04-24 no secrets, markers, links, markdown hygiene"
ckp "no secret patterns in T04 outputs" bash -c "test -s $MP && ! grep -nE 'sk-ant-[A-Za-z0-9]|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20}|xox[bp]-' $MP $TR $DF $TP"
ckp "no TODO/TBD/FIXME markers in master plan" no_markers "$MP"
ckp "relative links in master plan and TRACEABILITY resolve" links_resolve "$MP" "$TR"
ckp "no external image or script assets in master plan" bash -c "test -s $MP && ! grep -nE '<(img|script)[^>]+src=\"https?://|!\\[[^]]*\\]\\(https?://' $MP"
if [ -x .tools/pre-commit ]; then
  ckp "pre-commit run on T04 files passes" .tools/pre-commit run --files $MP $TR $DF $TP $RD
else printf '  SKIP  pre-commit not installed (.tools/pre-commit missing)\n'; fi
if command -v markdownlint >/dev/null 2>&1; then ckp "markdownlint clean" markdownlint $MP $DF; else printf '  SKIP  markdownlint not installed\n'; fi

echo "== TC-T04-25 solution-architect decisions D-1 to D-6 reflected; D-6 not yet adopted (snapshot)"
cka "Blocked-at-close policy is marked as pending owner confirmation (not adopted as policy)" gsall "$MP" 'conventions' 'pending' 'owner confirm'
cka "T00 to T02 precedent (owner acceptance recorded case by case) stays the rule until confirmed" gs "$MP" 'conventions' 'T00.*T02|precedent'
ckp "granularity: planned tests at FR/NFR level, 49 rows, R rows link to them" g "$MP" 'FR/NFR level|49 rows|FR and NFR'

echo
if [ $REG -eq 1 ]; then
  echo "NOTE: --regression mode: $excluded at-close (snapshot) checks excluded because they are true only at the close of T04; $ran invariant checks executed."
else
  echo "NOTE: full mode: $ran checks executed (at-close checks included)."
fi
if [ $fail -eq 0 ]; then echo "RESULT: ALL AUTOMATED CHECKS PASSED"; else echo "RESULT: ONE OR MORE CHECKS FAILED"; fi
exit $fail
