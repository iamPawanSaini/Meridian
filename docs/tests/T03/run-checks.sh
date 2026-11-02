#!/usr/bin/env bash
# Automated checks for T03 (technical design, docs-only). Designed from the acceptance criteria
# in docs/TASKS.md and the approved plan docs/tasks/T03/plan.md, not from the finished documents.
# Usage: docs/tests/T03/run-checks.sh   (exits non-zero if any check fails)
# A missing document makes every dependent check FAIL; nothing passes vacuously.
# Layout assumed (plan): docs/architecture/technical-design.md with sections D1..D8 as '#' headings;
# docs/specs/data-model.md (see check_data_model.py); docs/architecture/openapi.yaml; .spectral.yaml.
# shellcheck disable=SC2329 # T04a: functions are invoked indirectly through ck/py/check ("$@")
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
T=docs/tests/T03

fail=0
pass() { printf '  PASS  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=1; }
ck()   { local d=$1; shift; if "$@" >/dev/null 2>&1; then pass "$d"; else bad "$d"; fi; }
# run a python checker, show its lines, fold failure into the total
py()   { local out; out=$("$@" 2>&1); local rc=$?; printf '%s\n' "$out" | grep -vE '^RESULT:|^$'; [ $rc -ne 0 ] && fail=1; return 0; }

TD=docs/architecture/technical-design.md
DM=docs/specs/data-model.md
OA=docs/architecture/openapi.yaml
SA=docs/architecture/solution-architecture.md
TR=docs/TRACEABILITY.md
EX=.env.example
SP=.spectral.yaml

# g FILE ERE : file non-empty and contains pattern (case-insensitive)
g() { [ -s "$1" ] && grep -qiE -- "$2" "$1"; }
# sec FILE HEADING_REGEX : section from matching heading to the next heading of same or higher level
sec() { [ -s "$1" ] || return 1
  awk -v re="$2" '/^#+ /{match($0,/^#+/); l=RLENGTH; if(on&&l<=lv)on=0;
       if(!on && tolower($0) ~ tolower(re)){on=1;lv=l}} on' "$1"; }
# gs FILE HEADING_REGEX ERE : pattern occurs inside the named section
gs() { sec "$1" "$2" | grep -qiE -- "$3"; }

echo "== TC-T03-01 technical-design.md structure D1..D8, requirement map"
ck "technical-design.md exists and non-empty" test -s "$TD"
for n in 1 2 3 4 5 6 7 8; do ck "heading for D$n" g "$TD" "^#+ .*\bD$n\b"; done
ck "links to data-model.md"  g "$TD" 'data-model\.md'
ck "links to openapi.yaml"   g "$TD" 'openapi\.yaml'
ck "requirement map names R-04, R-06 and R-09" bash -c "grep -qE 'R-04' $TD && grep -qE 'R-06' $TD && grep -qE 'R-09' $TD"
ck "data-model.md exists and non-empty" test -s "$DM"

echo "== TC-T03-02 Drupal content model: five bundles, every field typed, validated, indexed"
py python3 -I $T/check_data_model.py
ck "(sentinel) data-model checker exited 0" python3 -I $T/check_data_model.py

echo "== TC-T03-03 Postgres schema: tables, keys, unique constraints, indexes (shares checker with 02)"
ck "all seven tables have subsections (runs, watchlist_snapshots, prices, decisions, positions, outbox, alembic_version)" bash -c "
  for t in runs watchlist_snapshots prices decisions positions outbox alembic_version; do grep -qiE \"^#+ .*\\b\$t\\b\" $DM || exit 1; done"
ck "decisions unique (trade_date, symbol, mode) for rerun idempotency" bash -c "tr '\n' ' ' < $DM | grep -qiE 'unique[^.]{0,80}trade_date[^.]{0,30}symbol[^.]{0,30}mode'"
ck "five FR-12 provenance columns named in Postgres decisions section" bash -c "
  s=\$(awk '/^#+ .*decisions/{on=1;next}/^#+ /{on=0}on' $DM)
  for r in 'inputs?_?snapshot' 'raw_?llm|raw_?output' 'prompt_?version' 'model' 'rule_?version'; do echo \"\$s\" | grep -qiE \"\$r\" || exit 1; done"

echo "== TC-T03-04 migration plan"
ck "baseline Alembic revision in T14" g "$TD" 'baseline.*(revision|migration)|(revision|migration).*baseline'
ck "mentions Alembic and T14" bash -c "grep -qi alembic $TD $DM && grep -qE 'T14' $TD"
ck "revision naming NNNN_slug" g "$TD" 'NNNN_slug|[0-9]{4}_[a-z_]+'
ck "downgrade tested for each revision" g "$TD" 'downgrade'
ck "forward-only in dev stated" g "$TD" 'forward-only|forward only'
ck "migration plan is in a headed section" g "$TD" '^#+ .*(migration)'

echo "== TC-T03-05 idempotency rule (D3)"
ck "idempotency section exists (heading)" g "$TD" '^#+ .*idempoten'
ck "external ID per record type, deterministic format with dec- prefix" g "$TD" 'dec-\{?[a-z_]*date'
ck "external ID formats for position and run" bash -c "grep -qiE 'pos-' $TD && grep -qiE 'run-' $TD"
ck "upsert semantics: create, update, unchanged" bash -c "for w in create update unchanged; do grep -qi \"\$w\" $TD || exit 1; done"
ck "payload hash used for unchanged detection" g "$TD" 'payload[_ ]hash|sha-?256'
ck "source_version stale rejection" g "$TD" 'source_version'
ck "stale record rejected (not applied)" g "$TD" 'stale'
ck "rerun of same date defined (what is the 'same record')" g "$TD" 'rerun|re-run'
ck "same payload twice yields unchanged, no duplicate (stated)" g "$TD" 'no duplicate|not duplicate|never duplicate|exactly one'

echo "== TC-T03-06 outbox and retry design (D4)"
ck "outbox section exists (heading)" g "$TD" '^#+ .*outbox'
ck "row lifecycle pending -> sent / dead" bash -c "for w in pending sent dead; do grep -qi \"\$w\" $TD || exit 1; done"
ck "one pending row per (record_type, external_id)" g "$TD" 'one pending.*(record_type|external)|(record_type|external).*one pending'
ck "backoff with 120 s cap (RK-04)" bash -c "grep -qi backoff $TD && grep -qE '120 ?s|120 seconds' $TD"
ck "wake request before publishing" g "$TD" 'wake'
ck "401 triggers token refresh" g "$TD" '401[^|]{0,80}(refresh|new token|re-?auth)'
ck "422 goes to dead-letter and raises an alert" bash -c "grep -qE '422' $TD && grep -qiE 'dead[- ]letter|dead' $TD && grep -qiE 'alert' $TD"
ck "published: partial rule" g "$TD" 'published.{0,6}partial|partial'
ck "batch size stated (500)" g "$TD" '\b500\b'
ck "drain triggers (next run, manual publish dispatch)" bash -c "grep -qi 'publish' $TD && grep -qiE 'next (scheduled )?run' $TD && grep -qiE 'NFR-15' $TD"
ck "Mermaid sequence diagram present" g "$TD" '^[[:space:]]*sequenceDiagram'
ck "mermaid fences balanced" bash -c "[ \$(( \$(grep -c '^\`\`\`' $TD) % 2 )) -eq 0 ] && [ \$(grep -c '^\`\`\`' $TD) -ge 2 ]"

echo "== TC-T03-07 OpenAPI structural validation (PyYAML)"
py python3 -I $T/validate_openapi.py "$OA"
ck "(sentinel) validate_openapi.py exited 0" python3 -I $T/validate_openapi.py "$OA"

echo "== TC-T03-08 validator self-test (rejects each seeded defect)"
py python3 -I $T/selftest_validator.py
ck "(sentinel) selftest exited 0" python3 -I $T/selftest_validator.py

echo "== TC-T03-09 Spectral ruleset file (lint itself is owner-run, TC-T03-10)"
ck ".spectral.yaml exists at repo root" test -s "$SP"
ck ".spectral.yaml extends spectral:oas" g "$SP" 'spectral:oas'
ck ".spectral.yaml parses as YAML mapping" python3 -I -c "import yaml,sys; assert isinstance(yaml.safe_load(open('$SP')),dict)"
spectral_rules_on() { [ -s "$SP" ] && ! grep -E "(operation-operationId|oas3-schema|oas3-valid-schema-example|no-[\$]ref-siblings|operation-success-response)['\"]?: *(off|false)" "$SP"; }
ck ".spectral.yaml does not switch off core rules wholesale (no rule set to off/false for operationId, schema, example, success-response)" spectral_rules_on
ck "openapi.yaml referenced by TD with the exact lint command" g "$TD" 'spectral.*lint.*openapi\.yaml'

echo "== TC-T03-11 authentication: clients, scopes, tokens (D6)"
ck "auth section exists (heading)" g "$TD" '^#+ .*(auth)'
for sc in meridian_ingest meridian_watchlist_read meridian_dashboard_read; do ck "scope $sc in technical-design.md" g "$TD" "$sc"; done
ck "OAuth client credentials grant for engine" g "$TD" 'client[_ -]credentials'
ck "Simple OAuth named, version check deferred to T10" bash -c "grep -qi 'simple oauth' $TD && grep -qE 'T10' $TD"
ck "token lifetimes stated (seconds or minutes)" g "$TD" 'lifetime|expires?[_ ]in|TTL'
ck "key-file storage local and Pantheon" bash -c "grep -qiE 'private key|key[- ]file|keys? (path|dir)' $TD && grep -qi pantheon $TD"
ck "final Drupal role list: administrator, analyst, engine-ingest, dashboard-read" bash -c "for r in administrator analyst engine-ingest dashboard-read; do grep -qi \"\$r\" $TD || exit 1; done"
ck "authorisation matrix (role x endpoint) present" g "$TD" 'authori[sz]ation matrix|role.{0,10}endpoint|permission(s)? matrix'
ck "scopes consistent: openapi.yaml scopes also appear in technical-design.md" bash -c "
  for s in \$(grep -oE 'meridian_[a-z_]+' $OA | sort -u); do grep -q \"\$s\" $TD || { echo missing \$s; exit 1; }; done; grep -q meridian_ $OA"

echo "== TC-T03-12 user login flow and session (D6)"
ck "authorisation code grant" g "$TD" 'authori[sz]ation[ _-]code'
ck "PKCE" g "$TD" 'PKCE'
ck "separate confidential client meridian-web-login (or an explicit alternative decision recorded)" g "$TD" 'meridian-web-login'
ck "confidential, server-side client" bash -c "grep -qi confidential $TD && grep -qiE 'server-side|server side' $TD"
ck "session cookie flags HttpOnly, Secure, SameSite" bash -c "for f in httponly secure samesite; do grep -qi \"\$f\" $TD || exit 1; done"
ck "login and logout/expiry behaviour described (redirect to login)" g "$TD" 'redirect|logout|log out|sign[- ]?out'
ck "tokens never reach the browser (FR-21)" g "$TD" 'FR-21'

echo "== TC-T03-13 revalidation route and secret"
ck "revalidation route path stated (/api/revalidate or similar)" g "$TD" '/api/revalidate|revalidate.{0,40}/api/|/api/[a-z/-]*revalidat'
ck "revalidation secret named on both sides (Drupal and Next.js)" bash -c "grep -qiE 'revalidat[a-z_ ]*secret|REVALIDATE_SECRET|REVALIDATION_SECRET' $TD && grep -qi drupal $TD && grep -qiE 'next(\\.js)?' $TD"
ck "revalidate interval 300 s" g "$TD" '300 ?s|300 seconds'
ck "T02 RK-07 now names the revalidation secret" bash -c "grep -E '^\\| RK-07' $SA | grep -qiE 'REVALIDAT[A-Z_]*SECRET|revalidation secret'"

echo "== TC-T03-14 env matrix parity with .env.example (names, both directions)"
py python3 -I $T/check_env_parity.py
ck "(sentinel) check_env_parity.py exited 0" python3 -I $T/check_env_parity.py

echo "== TC-T03-15 env matrix covers four environments and every consumer (D7)"
ck "matrix section exists" g "$TD" '^#+ .*environment.*secret'
for e in 'DDEV' 'Pantheon' 'Vercel' 'GitHub Actions'; do ck "environment: $e" gs "$TD" '^#+ .*environment.*secret' "$e"; done
ck "rule: Drupal base URL server-only, no NEXT_PUBLIC_ prefix" g "$TD" 'server-only|server only'
ck "secret store stated per secret (GitHub Secrets / Vercel env / Pantheon secrets / .env)" gs "$TD" '^#+ .*environment.*secret' 'github secrets|repository secrets|vercel'
ck ".env.example grouped by consumer (>= 3 section comments)" bash -c "[ \$(grep -cE '^# ---' $EX) -ge 3 ]"
ck ".env.example has no real secrets (no sk-ant-, AKIA, private key blocks)" bash -c "! grep -qE 'sk-ant-|AKIA[0-9A-Z]{12}|BEGIN [A-Z ]*PRIVATE KEY' $EX"

echo "== TC-T03-16 repo and deploy strategy (D8)"
ck "deploy section exists (heading)" g "$TD" '^#+ .*(repo|deploy)'
ck "Composer root apps/drupal, docroot web" bash -c "grep -q 'apps/drupal' $TD && grep -qE 'docroot.{0,40}web|web/' $TD"
ck "config/sync path" g "$TD" 'config/sync'
ck "DDEV composer_root setting" g "$TD" 'composer_root'
ck "subtree split and push to Pantheon (ADR-0004)" bash -c "grep -qi 'subtree' $TD && grep -qE 'ADR-0004' $TD"
ck "how apps/drupal reaches Pantheon: workflow deploy-drupal.yml" g "$TD" 'deploy-drupal\.yml'
ck "Pantheon credential: Terminus token and deploy key" bash -c "grep -qi terminus $TD && grep -qiE 'deploy key|ssh key' $TD"
ck "Vercel root apps/web" g "$TD" 'apps/web'
ck "engine image from services/engine" g "$TD" 'services/engine'
ck "workflow names ci.yml, daily-run.yml, deploy-drupal.yml" bash -c "for w in ci.yml daily-run.yml deploy-drupal.yml; do grep -q \"\$w\" $TD || exit 1; done"
ck "items ADR-0004 left unverified listed for T07" bash -c "grep -qi unverified $TD && grep -qE 'T07' $TD"

echo "== TC-T03-17 NFR numbers owned by T03"
ck "NFR-04 value in technical-design.md" bash -c "grep -qE 'NFR-04' $TD"
ck "NFR-05 value in technical-design.md" bash -c "grep -qE 'NFR-05' $TD"
ck "payload size limit and rate limit numbers for T10" bash -c "grep -qiE '[0-9]+ ?(KB|MB|KiB|MiB)' $TD && grep -qiE '[0-9]+ ?(requests?|req)(/| per )(min|minute|s|sec)' $TD"
ck "provisional values name their confirming gate (measurement before T10)" bash -c "grep -qi provisional $TD && grep -qiE 'measure' $TD && grep -qE 'T10' $TD"
ck "Pantheon request time limit recorded with source or marked unverified" bash -c "grep -qiE 'request (time|timeout)|time limit|timeout' $TD && grep -qiE 'unverified|https?://' $TD"
nfr_rows_ok() { [ -s "$SA" ] && [ "$(grep -E '^\| *NFR-0[45] *\|' "$SA" | grep -ciE 'technical-design')" -eq 2 ]; }
ck "T02 follow-ups: NFR-04 and NFR-05 table rows in SA point to technical-design (exactly 2 rows)" nfr_rows_ok
ck "T02 follow-ups: OQ-01 and OQ-07 resolution updated" bash -c "grep -E '^\\| OQ-01' $SA | grep -qiE 'resolved|decided|decision' && grep -E '^\\| OQ-07' $SA | grep -qiE 'technical-design'"
ck "T02 follow-ups: SA sign-off has a T03 amendment line" gs "$SA" '^#+ .*sign-off' 'T03 amendment'

echo "== TC-T03-18 TRACEABILITY: design element (T03) non-empty for R-01..R-12"
ck "TRACEABILITY header has 'Design element (T03)' column" g "$TR" 'Design element \(T03\)'
if ! python3 -I - "$TR" <<'PY'
import re, sys
rows = [l for l in open(sys.argv[1]).read().splitlines() if l.startswith("|")]
cells = lambda l: [c.strip() for c in l.strip().strip("|").split("|")]
hdr = next((cells(l) for l in rows if "Design element" in l), None)
bad = 0
def out(ok, msg):
    global bad
    print(("  PASS  " if ok else "  FAIL  ") + msg); bad += (not ok)
if not hdr: out(False, "header row found"); sys.exit(1)
i = next(k for k, c in enumerate(hdr) if "Design element" in c)
found = {}
for l in rows:
    c = cells(l)
    if re.fullmatch(r"R-\d\d", c[0]): found[c[0]] = c
for n in range(1, 13):
    r = f"R-{n:02d}"
    c = found.get(r)
    out(bool(c) and len(c) > i and c[i] != "" and not re.fullmatch(r"(?i)tbd|todo|-|n/a", c[i]), f"{r} has a non-empty design element cell")
    out(bool(c) and len(c) > i and bool(re.search(r"technical-design|data-model|openapi|\bD[1-8]\b|ADR|solution-architecture", c[i])), f"{r} design element cites a document or D-section")
sys.exit(1 if bad else 0)
PY
then fail=1; fi

echo "== TC-T03-19 solution-architect sign-off recorded"
ck "sign-off section in technical-design.md" g "$TD" '^#+ .*sign-off'
ck "sign-off names solution-architect" gs "$TD" '^#+ .*sign-off' 'solution-architect'
ck "sign-off has an ISO date" gs "$TD" '^#+ .*sign-off' '20[0-9]{2}-[0-9]{2}-[0-9]{2}'
ck "sign-off states approved" gs "$TD" '^#+ .*sign-off' 'approved|signed off'
ck "no unresolved TODO/TBD/FIXME markers left in design docs or openapi" bash -c "test -s $TD && test -s $DM && test -s $OA && ! grep -nE '\\b(TODO|TBD|FIXME|XXX)\\b' $TD $DM $OA"
ck "status line is not Draft" bash -c "test -s $TD && grep -qiE '^\\| *status *\\|' $TD && ! grep -m3 -iE '^\\| *status *\\|.*draft' $TD"

echo "== TC-T03-20 check-names.sh passes (C4 limited, no stale names)"
ck "scripts/check-names.sh exits 0" scripts/check-names.sh
ck "T03 documents use current names (meridian_engine, meridian_ingest, meridian-web)" bash -c "grep -q meridian_ingest $TD && grep -q meridian-web $TD"

echo "== TC-T03-21 simulation only: no broker names or trading domains in T03 artefacts"
BR='zerodha|kite ?connect|\bkite\b|upstox|angel ?(one|broking)|groww|fyers|5paisa|dhanhq|\bdhan\b|alice ?blue|interactive ?brokers|alpaca|icici ?direct|place[_ -]?order|order[_ -]?placement'
ck "all T03 artefacts exist (so the grep is not vacuous)" bash -c "test -s $TD && test -s $DM && test -s $OA && test -s $SP"
ck "no broker names in technical-design.md, data-model.md, openapi.yaml, .env.example, .spectral.yaml" bash -c "test -s $TD && test -s $DM && test -s $OA && test -s $SP && ! grep -niE '$BR' $TD $DM $OA $EX $SP"
ck "no trading-domain hostnames in openapi servers" bash -c "test -s $OA && ! grep -niE 'https?://[a-z0-9.-]*(zerodha|kite|upstox|angelone|groww|fyers)' $OA"
ck "design states simulation-only / no live trading (ADR-0006)" g "$TD" 'simulation|ADR-0006'

echo "== TC-T03-22 no secrets, markdown hygiene, links"
ck "no secret patterns in T03 docs and openapi" bash -c "test -s $TD && ! grep -nE 'sk-ant-[A-Za-z0-9]|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20}|xox[bp]-' $TD $DM $OA $EX"
if [ -x .tools/pre-commit ]; then
  ck "pre-commit run on T03 files passes" .tools/pre-commit run --files $TD $DM $OA $EX $SP
else printf '  SKIP  pre-commit not installed (.tools/pre-commit missing)\n'; fi
ck "relative markdown links in TD and DM resolve" python3 -I - <<'PY'
import re, sys, os
bad = []
for f in ("docs/architecture/technical-design.md", "docs/specs/data-model.md"):
    if not os.path.isfile(f): bad.append(f + " missing"); continue
    for m in re.finditer(r"\]\(([^)#\s]+)(#[^)]*)?\)", open(f).read()):
        t = m.group(1)
        if re.match(r"[a-z]+:", t): continue
        if not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(f), t))): bad.append(f"{f}: {t}")
print(bad[:5]); sys.exit(1 if bad else 0)
PY
ck "no external image/script assets in docs" bash -c "test -s $TD && ! grep -nE '<(img|script)[^>]+src=\"https?://|!\\[[^]]*\\]\\(https?://' $TD $DM"
if command -v markdownlint >/dev/null 2>&1; then ck "markdownlint clean" markdownlint $TD $DM; else printf '  SKIP  markdownlint not installed\n'; fi

echo
if [ $fail -eq 0 ]; then echo "RESULT: ALL AUTOMATED CHECKS PASSED"; else echo "RESULT: ONE OR MORE CHECKS FAILED"; fi
exit $fail
