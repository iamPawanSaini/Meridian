#!/usr/bin/env bash
# Automated structural checks for T02 (docs-only task). Designed from the acceptance
# criteria in docs/TASKS.md and the approved plan, not from the finished documents.
# Usage: docs/tests/T02/run-checks.sh   (exits non-zero if any check fails)
# A missing document makes every dependent check FAIL; nothing passes vacuously.
# Conventions assumed (from the plan): '##' section headings, Markdown tables for
# FR/NFR, risks, cost map, open questions and naming checks; ADR files docs/adr/ADR-000N-*.md.
# shellcheck disable=SC2329 # T04a: functions are invoked indirectly through ck/py/check ("$@")
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2

fail=0
pass() { printf '  PASS  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=1; }
ck()   { local d=$1; shift; if "$@" >/dev/null 2>&1; then pass "$d"; else bad "$d"; fi; }

SA=docs/architecture/solution-architecture.md
NM=docs/architecture/naming.md
TR=docs/TRACEABILITY.md
ADRDIR=docs/adr
DATE_RE='20[0-9]{2}-[0-9]{2}-[0-9]{2}'
RR='risk register'
CM='cost map'
OQ='open questions'

# sec FILE HEADING_REGEX: section from matching heading to next heading of same or higher level
sec() { [ -s "$1" ] || return 1
  awk -v re="$2" '/^#+ /{match($0,/^#+/); l=RLENGTH; if(on&&l<=lv)on=0;
       if(!on && tolower($0) ~ tolower(re)){on=1;lv=l}} on' "$1"; }
# rows FILE HEADING_REGEX: table rows of a section, header kept, separator dropped
rows() { sec "$1" "$2" | grep -E '^\|' | grep -vE '^\|[ :|-]+\|?[ ]*$'; }
has_sec() { [ -n "$(sec "$1" "$2")" ]; }
mermaid_body() { [ -s "$SA" ] && awk '/^```mermaid/{on=1;next}/^```/{on=0}on' "$SA"; }
adrf() { local f b
  for f in "$ADRDIR"/*; do b=${f##*/}
    if [[ $b =~ ^(ADR-)?000$1[-_].*\.md$ ]]; then echo "$ADRDIR/$b"; return 0; fi
  done; return 0; }
six_adrs() { local a=("$ADRDIR"/ADR-000[1-6]-*.md); [ -e "${a[0]}" ] && [ "${#a[@]}" -eq 6 ]; }

echo "== TC-T02-01 required sections in solution-architecture.md"
ck "file exists and non-empty" test -s "$SA"
for h in "context" "container" "data flow" "scope" "non-goals" "assumptions" "glossary" \
         "requirements" "risk register" "cost map" "open questions" "sign-off"; do
  ck "section heading: $h" has_sec "$SA" "^#+ .*$h"
done

echo "== TC-T02-02 Mermaid diagrams (context, container, daily-run sequence)"
ck ">=3 mermaid blocks" bash -c "[ \"\$(grep -c '^\`\`\`mermaid' $SA)\" -ge 3 ]"
ck ">=2 flowchart/graph" bash -c "[ \"\$(grep -cE '^[[:space:]]*(flowchart|graph) ' $SA)\" -ge 2 ]"
ck ">=1 sequenceDiagram" grep -qE '^[[:space:]]*sequenceDiagram' "$SA"
ck "code fences balanced" bash -c "[ \$(( \$(grep -c '^\`\`\`' $SA) % 2 )) -eq 0 ]"
ck "diagrams mention Postgres" bash -c "$(declare -f mermaid_body); SA=$SA; mermaid_body | grep -qi postgres"
ck "diagrams mention outbox"   bash -c "$(declare -f mermaid_body); SA=$SA; mermaid_body | grep -qi outbox"
ck "diagrams mention Drupal ingest" bash -c "$(declare -f mermaid_body); SA=$SA; mermaid_body | grep -qi ingest"
ck "diagrams mention JSON:API read path" bash -c "$(declare -f mermaid_body); SA=$SA; mermaid_body | grep -qiE 'json:?api'"

echo "== TC-T02-03 glossary terms"
for t in "trading day" "holiday calendar" "EOD candle" "Nifty 50" "circuit limit" "STT" \
         "long" "short" "score" "rule hit" "veto" "ATR" "stop" "target" "time-stop" \
         "R-multiple" "forward return" "alpha"; do
  ck "glossary term: $t" bash -c "$(declare -f sec); sec $SA '^#+ .*glossary' | grep -qiF -- '$t'"
done

echo "== TC-T02-04 every FR/NFR row has parent R-ID, MoSCoW, target, verifying task"
fr_check() { [ -s "$SA" ] || return 1
 awk -F'|' '
  function t(s){gsub(/^[ \t*`]+|[ \t*`]+$/,"",s);return s}
  /^\|/ && tolower($0) ~ /priority/ && tolower($0) ~ /target/ {
     p=pr=tg=v=0
     for(i=2;i<NF;i++){c=tolower(t($i)); if(c~/parent/)p=i; else if(c~/priority|moscow/)pr=i;
       else if(c~/target/)tg=i; else if(c~/verif/)v=i}
     if(!(p&&pr&&tg&&v)){print "header lacks a column";e++} next}
  /^\| *(N?FR)-[0-9]+/ { n++; id=t($2)
     if(!(p&&pr&&tg&&v)){print id": no header";e++;next}
     if(t($p) !~ /R-(0[1-9]|1[0-2])/){print id": parent R-ID";e++}
     if(t($pr) !~ /^(Must|Should|Could|Won.t)/){print id": MoSCoW";e++}
     if(t($tg)=="" || (t($tg) !~ /[0-9]/ && tolower(t($tg)) !~ /deferred to t03/)){print id": target";e++}
     if(t($v) !~ /T[0-9]+/){print id": verifying task";e++} }
  END{ if(n<12){print "only " n " FR/NFR rows";e++} exit e>0 }' "$SA"; }
ck "all FR/NFR rows complete (>=12 rows)" fr_check
ck "at least one NFR row" grep -qE '^\| *NFR-[0-9]+' "$SA"
ck "at least one FR row" grep -qE '^\| *FR-[0-9]+' "$SA"
ck "FR/NFR IDs unique and present" bash -c "ids=\$(grep -oE '^\| *N?FR-[0-9]+' $SA | tr -d '| '); [ -n \"\$ids\" ] && [ -z \"\$(sort <<<\"\$ids\" | uniq -d)\" ]"

echo "== TC-T02-05 named NFR targets exist with verifying task"
nfr() { grep -E '^\| *N?FR-[0-9]+' "$SA" | grep -iE -- "$1" | grep -qE -- "$2"; }
ck "engine run duration row"                 nfr 'run duration|runtime|engine run' 'T[0-9]+'
ck "data freshness row states an IST time"   nfr 'fresh' 'IST'
ck "dashboard LCP row -> T26"                nfr 'LCP|page load' 'T26'
ck "batch ingest of 500 records -> T10"      nfr 'ingest' '500.*T10|T10.*500'
ck "p95 row mentions 5,000 records"          nfr 'p95' '5,?000'
ck "p95 row verified by T11"                 nfr 'p95' 'T11'
ck "p95 row verified by T30"                 nfr 'p95' 'T30'
ck "availability row -> T31"                 nfr 'availab' 'T31'
ck "CI duration row -> T08"                  nfr 'CI ' 'T08'

echo "== TC-T02-06 every R-01..R-12 has a child FR/NFR in the architecture doc"
for i in $(seq -w 1 12); do
  ck "R-$i has a child" bash -c "grep -E '^\| *N?FR-[0-9]+' $SA | grep -q 'R-$i'"
done

echo "== TC-T02-08 risk register: seven named risks plus two extras"
risk() { rows "$SA" "^#+ .*$RR" | grep -iE -- "$1" | grep -qiE -- "$2"; }
ck "free data source blocking"           risk 'data source|data provider|yahoo|nse' 'block|ban|rate.?limit|scrap'
ck "LLM wrong or injected output"        risk 'LLM|Claude' 'inject|wrong|hallucin'
ck "free-tier limits changing"           risk 'free.?tier|limits' 'chang'
ck "Pantheon sandbox sleep"              risk 'Pantheon' 'sleep'
ck "GitHub cron delay"                   risk 'cron' 'delay'
ck "SEBI / regulatory exposure"          risk 'SEBI' 'regulat|exposure|advis'
ck "secrets leakage"                     risk 'secret' 'leak|exposure'
ck "LLM cost overrun (extra)"            risk 'LLM|Claude' 'cost|spend|budget'
ck "Vercel Hobby non-commercial (extra)" risk 'Vercel' 'non-?commercial|hobby'

echo "== TC-T02-09 each risk row has likelihood, impact, owner role, mitigation, linked task"
risk_complete() { rows "$SA" "^#+ .*$RR" | awk -F'|' '
  function t(s){gsub(/^[ \t*`]+|[ \t*`]+$/,"",s);return s}
  NR==1{for(i=2;i<NF;i++){c=tolower(t($i)); if(c~/likelihood/)l=i; else if(c~/impact/)im=i;
        else if(c~/owner/)o=i; else if(c~/mitigation/)m=i; else if(c~/task|link/)k=i}
        if(!(l&&im&&o&&m&&k)){print "header";e++}; next}
  { n++; if(length(t($l))<3||length(t($im))<3){print "L/I row " n;e++}
    if(tolower(t($o)) !~ /architect|developer|tester|owner|engineer|security|devops|maintainer/){print "owner row " n;e++}
    if(length(t($m))<10){print "mitigation row " n;e++}
    if(t($k) !~ /T[0-9]+/){print "task row " n;e++} }
  END{ if(n<9){print "fewer than 9 risks";e++} exit e>0 }'; }
ck "all risk rows complete (>=9 rows)" risk_complete

echo "== TC-T02-11 cost map classifies every component"
cost() { rows "$SA" "^#+ .*$CM" | grep -iE -- "$1" | tr -d '*`' | grep -qiE '\| *(free-with-limits|free with limits|free|paid) *\|'; }
for c in "GitHub Actions" "Postgres" "Pantheon" "Vercel" "Claude" "data source|market data|yfinance|NSE" "domain"; do
  ck "cost row classified: $c" cost "$c"
done
cost_cells() { rows "$SA" "^#+ .*$CM" | tail -n +2 | tr -d '*`' | awk -F'|' '
  function t(s){gsub(/^[ \t]+|[ \t]+$/,"",s);return tolower(s)}
  {ok=0; for(i=2;i<NF;i++){x=t($i); if(x=="free"||x=="free-with-limits"||x=="free with limits"||x=="paid")ok++}
   if(ok!=1){print "row without exactly one class: " $0; e++} n++}
  END{exit (e>0||n<7)}'; }
ck "each cost row has exactly one class cell (>=7 rows)" cost_cells
ck "cost header has a limit column" bash -c "$(declare -f rows sec); rows $SA '^#+ .*$CM' | head -1 | grep -qi limit"

echo "== TC-T02-13 six ADR files with matching topics"
adr_topic() { local f; f="$(adrf "$1")"; [ -n "$f" ] && head -3 "$f" | grep -qiE -- "$2"; }
ck "ADR-0001 headless Drupal + Next.js" adr_topic 1 'drupal'
ck "ADR-0002 engine on GitHub Actions"  adr_topic 2 'github actions'
ck "ADR-0003 Postgres system of record" adr_topic 3 'postgres'
ck "ADR-0004 monorepo subtree Pantheon" adr_topic 4 'monorepo|subtree|pantheon'
ck "ADR-0005 authentication"            adr_topic 5 'auth'
ck "ADR-0006 no live trading"           adr_topic 6 'live trading|no live'

echo "== TC-T02-14 each ADR has all template fields with content"
adr_fields() { local f; f="$(adrf "$1")"; [ -n "$f" ] || return 1
  grep -qE "^# ADR-000$1" "$f" &&
  grep -qiE '^\| *Status *\| *(Proposed|Accepted|Superseded by ADR-[0-9]{4})' "$f" &&
  grep -qiE "^\| *Date *\| *$DATE_RE" "$f" &&
  grep -qiE '^\| *Deciders *\|' "$f" &&
  for h in Context Decision "Alternatives considered" Consequences; do
    awk -v h="$h" '/^## /{on=(tolower(substr($0,4))==tolower(h));next} on&&NF{n++} END{exit n<1}' "$f" || return 1
  done &&
  [ "$(awk '/^## Alternatives considered/{on=1;next}/^## /{on=0} on&&/^\|/' "$f" | grep -vcE '^\|[ :|-]+\|?$')" -ge 3 ] &&
  grep -q 'Positive' "$f" && grep -q 'Negative' "$f" && grep -q 'Follow-ups' "$f"; }
for n in 1 2 3 4 5 6; do
  ck "ADR-000$n fields (Status, Date, Deciders, Context, Decision, Alternatives >=2 options, Consequences)" adr_fields $n
done
ck "exactly six ADR files and no template placeholders left" bash -c "$(declare -f six_adrs); ADRDIR=$ADRDIR; six_adrs && ! grep -lE '<title>|YYYY-MM-DD|ADR-000x|<The forces|<What we will' $ADRDIR/ADR-000[1-6]-*.md | grep -q ."

echo "== TC-T02-15 ADR index"
for n in 1 2 3 4 5 6; do ck "docs/adr/README.md lists ADR-000$n" grep -qE "ADR-000$n|000$n-" "$ADRDIR/README.md"; done

echo "== TC-T02-16 ADR content anchors"
adr_has() { local f; f="$(adrf "$1")"; [ -n "$f" ] && shift && for p in "$@"; do grep -qiE -- "$p" "$f" || return 1; done; }
ck "ADR-0006: simulation, orders, T33"            adr_has 6 'simulation' 'order' 'T33'
ck "ADR-0003: Drupal is a published copy"         adr_has 3 'published copy|copy'
ck "ADR-0005: client credentials + least privilege/scope" adr_has 5 'client.credentials' 'least.privilege|scope'
ck "ADR-0004: apps/drupal subtree"                adr_has 4 'apps/drupal' 'subtree'
ck "ADR-0002: cron / schedule"                    adr_has 2 'cron|schedul'
ck "ADR-0001: headless"                           adr_has 1 'headless' 'next'

echo "== TC-T02-17 naming.md five checks, each with method, source, date, result"
ck "naming.md exists" test -s "$NM"
nrow() { grep -E '^\| *[0-9]+ *\|' "$NM" 2>/dev/null | grep -iE -- "$1"; }
nrow_ok() { local r l; r="$(nrow "$1")"; [ -n "$r" ] || return 1
  while IFS= read -r l; do
    grep -qE -- "$DATE_RE" <<<"$l" && grep -qiE 'https?://|not verifiable by agent' <<<"$l" || return 1
  done <<<"$r"; }
ck ".com domain row dated and sourced"        nrow_ok '\.com'
ck ".in domain row dated and sourced"         nrow_ok '\.in\b'
ck "GitHub handle row dated and sourced"      nrow_ok 'github'
ck "Vercel handle row dated and sourced"      nrow_ok 'vercel'
ck "IP India trademark row dated and sourced" nrow_ok 'IP India'
ck "trademark classes 9, 36, 42 named"        bash -c "$(declare -f nrow); NM=$NM; for c in 9 36 42; do nrow 'IP India' | grep -qE \"\\b\$c\\b\" || exit 1; done"
ck "Play Store row dated and sourced"         nrow_ok 'play store'
ck "App Store row dated and sourced"          nrow_ok 'app store'
ck "repo Meridian vs meridian mismatch recorded" grep -qiE 'Meridian.*(vs|versus|mismatch|lowercase).*meridian|T00.*finding' "$NM"

echo "== TC-T02-18 naming.md exactly one outcome"
OUTRE='^[[:space:]>*-]*\**outcome\**[[:space:]]*:'
ck "exactly one Outcome line" bash -c "[ \"\$(grep -ciE '$OUTRE' $NM)\" = 1 ]"
classify() { local l c=0; l="$(grep -iE "$OUTRE" "$NM" | head -1)"
  if grep -qiE 'internal codename' <<<"$l"; then c=1
  else grep -qiE '\brename\b' <<<"$l" && c=$((c+1)); grep -qiE '\bkeep\b' <<<"$l" && c=$((c+1)); fi
  [ "$c" -eq 1 ]; }
ck "outcome is exactly one of: keep / keep as internal codename only / rename" classify
ck "outcome has no unresolved markers" bash -c "grep -iE '$OUTRE' $NM | grep -q . && ! grep -iE '$OUTRE' $NM | grep -qiE 'tbd|todo|one of|pending'"

echo "== TC-T02-19 check-names.sh (positive, then negative control)"
ck "check-names.sh passes on tree" scripts/check-names.sh
printf '%s\n' "trading""-agent" > docs/tests/T02/zz-negative-control.txt
ck "check-names.sh rejects a planted stale name" bash -c "! scripts/check-names.sh"
rm -f docs/tests/T02/zz-negative-control.txt
ck "negative control file removed and check-names passes again" scripts/check-names.sh
ck "if outcome is rename, TASKS.md section 0 changed vs main (vacuous otherwise)" bash -c "[ -s $NM ] && { ! grep -iE '$OUTRE' $NM | grep -qiE '\brename\b' || ! git diff --quiet main -- docs/TASKS.md; }"

echo "== TC-T02-21 free-tier / regulatory claims carry URL + date, or 'unverified'"
claims() { rows "$SA" "^#+ .*$CM" | tail -n +2
           rows "$SA" "^#+ .*$RR" | tail -n +2 | grep -iE 'free.?tier|hobby|sleep|SEBI|cron|pricing|per (month|million)|limit|non-?commercial'; }
claims_ok() { local r l; r="$(claims)"; [ -n "$r" ] || return 1
  while IFS= read -r l; do
    { grep -qE 'https?://' <<<"$l" && grep -qE -- "$DATE_RE" <<<"$l"; } || grep -qi 'unverified' <<<"$l" || { echo "UNCITED: $l"; return 1; }
  done <<<"$r"; }
ck "every cost row and limit/regulatory risk row has URL+date or 'unverified'" claims_ok
ck "no plain http:// URLs" bash -c "[ -s $SA ] && [ -s $NM ] && ! grep -hoE 'http://[^ )|>]+' $SA $NM | grep -q ."

echo "== TC-T02-22 no external images or hosted assets"
ASSETS="$SA $NM $ADRDIR/ADR-000[1-6]-*.md"
ck "doc set exists for asset scan" bash -c "[ -s $SA ] && [ -s $NM ] && [ \$(ls $ADRDIR/ADR-000[1-6]-*.md | wc -l) -eq 6 ]"
ck "no markdown images" bash -c "[ -s $SA ] && ! grep -nE '!\[[^]]*\]\(' $ASSETS 2>/dev/null | grep -q ."
ck "no HTML img/script/iframe/link tags" bash -c "[ -s $SA ] && ! grep -niE '<(img|script|iframe|link|object|embed)\b' $ASSETS 2>/dev/null | grep -q ."
ck "no diagram or badge hosts" bash -c "[ -s $SA ] && ! grep -niE 'mermaid\.ink|kroki|plantuml|shields\.io|imgur|githubusercontent|cdn\.|unpkg|jsdelivr|googleapis|draw\.io|diagrams\.net' $ASSETS 2>/dev/null | grep -q ."
ck "no image files under docs/architecture or docs/adr" bash -c "[ -s $SA ] && ! git ls-files --others --cached docs/architecture docs/adr | grep -iE '\.(png|jpe?g|gif|svg|webp|pdf)$' | grep -q ."

echo "== TC-T02-23 no broker SDK names or trading domains"
BROKER='kiteconnect|zerodha|upstox|angelone|angel one|smartapi|dhan|fyers|5paisa|alice ?blue|iifl|breeze|kite\.trade'
ck "scan targets exist" bash -c "[ -s $SA ] && [ -s $NM ] && [ \$(ls $ADRDIR/ADR-000[1-6]-*.md | wc -l) -eq 6 ]"
ck "no broker names in T02 outputs" bash -c "[ -s $SA ] && [ -s $NM ] && ! grep -rniE '$BROKER' $SA $NM $TR $ADRDIR docs/architecture/README.md 2>/dev/null | grep -q ."
ck "no broker names in code/config dirs" bash -c "! git grep -niE '$BROKER' -- apps services scripts .github .ddev ':!scripts/check-names.sh' 2>/dev/null | grep -q ."
ck "docs state the simulation-only rule" bash -c "grep -qiE 'simulation' $SA && grep -qiE 'no live|never place|simulation.only' $SA"

echo "== TC-T02-24 open questions resolved or ticketed"
oq() { rows "$SA" "^#+ .*$OQ" | tail -n +2; }
oq_ok() { local r l; r="$(oq)"; [ -n "$r" ] || return 1
  while IFS= read -r l; do
    grep -qiE 'resolved|T[0-9]+a?\b' <<<"$l" || { echo "OPEN: $l"; return 1; }
    ! grep -qiE '\b(tbd|todo|unknown)\b' <<<"$l" || { echo "TBD: $l"; return 1; }
  done <<<"$r"; }
ck "open questions table non-empty; every row resolved or ticketed" oq_ok
ticket_exists() { local ids t; ids="$(oq | grep -oE '\bT[0-9]+a?\b' | sort -u)"; [ -n "$ids" ] || { [ -n "$(oq)" ]; return; }
  for t in $ids; do grep -qE "^## $t:" docs/TASKS.md || { echo "no such task $t"; return 1; }; done; }
ck "every ticket task ID exists in TASKS.md" ticket_exists
ck "open questions table has owner column" bash -c "$(declare -f rows sec); rows $SA '^#+ .*$OQ' | head -1 | grep -qi owner"

echo "== TC-T02-25 technical-architect sign-off recorded"
so() { sec "$SA" '^#+ .*sign-off'; }
ck "sign-off names technical-architect" bash -c "$(declare -f sec so); SA=$SA; so | grep -qi 'technical-architect'"
ck "sign-off says approved/signed off"  bash -c "$(declare -f sec so); SA=$SA; so | grep -qiE 'approved|signed off'"
ck "sign-off has a date"                bash -c "$(declare -f sec so); SA=$SA; so | grep -qE '$DATE_RE'"
ck "sign-off not pending/conditional"   bash -c "$(declare -f sec so); SA=$SA; so | grep -q . && ! so | grep -qiE 'pending|tbd|not (yet )?signed|conditional'"
ck "review.md exists" test -s docs/tasks/T02/review.md

echo "== TC-T02-26 TRACEABILITY lists refined IDs for R-01..R-12"
for i in $(seq -w 1 12); do
  ck "TRACEABILITY R-$i row lists an FR/NFR ID" bash -c "grep -E '^\| R-$i \|' $TR | grep -qE 'N?FR-[0-9]+'"
done
ck "original columns intact" bash -c "h=\$(grep -E '^\| Req \|' $TR); grep -q Requirement <<<\"\$h\" && grep -q Tasks <<<\"\$h\" && grep -q Status <<<\"\$h\""
ck "all 12 R rows present" bash -c "[ \$(grep -cE '^\| R-(0[1-9]|1[0-2]) \|' $TR) -eq 12 ]"
tr_ids() { grep -E '^\| R-[0-9]+ \|' "$TR" | grep -oE 'N?FR-[0-9]+' | sort -u; }
sa_ids() { grep -E '^\| *N?FR-[0-9]+' "$SA" | grep -oE '^\| *N?FR-[0-9]+' | tr -d '| ' | sort -u; }
ck "every architecture FR/NFR ID appears in TRACEABILITY" bash -c "$(declare -f tr_ids sa_ids); TR=$TR; SA=$SA; [ -n \"\$(sa_ids)\" ] && [ -z \"\$(comm -13 <(tr_ids) <(sa_ids))\" ]"
ck "no TRACEABILITY FR/NFR ID missing from architecture" bash -c "$(declare -f tr_ids sa_ids); TR=$TR; SA=$SA; [ -n \"\$(tr_ids)\" ] && [ -z \"\$(comm -23 <(tr_ids) <(sa_ids))\" ]"
ck "TRACEABILITY pairing matches parent R-ID in architecture doc" bash -c "
 [ -s $SA ] && grep -qE 'FR-[0-9]+' $TR || exit 1
 for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
   for id in \$(grep -E \"^\\| R-\$i \\|\" $TR | grep -oE 'N?FR-[0-9]+'); do
     grep -E \"^\\| *\$id *\\|\" $SA | grep -q \"R-\$i\" || exit 1; done; done"

echo "== TC-T02-27 C1/C2 plan and review exist"
ck "plan exists and is Approved" grep -qi 'Approved' docs/tasks/T02/plan.md
ck "review exists" test -s docs/tasks/T02/review.md
ck "review records approval" grep -qiE 'approv' docs/tasks/T02/review.md

echo "== TC-T02-28 C5 docs updated"
ck "architecture README links solution-architecture and naming" bash -c "grep -q 'solution-architecture' docs/architecture/README.md && grep -q 'naming' docs/architecture/README.md"

echo "== TC-T02-29 C6 no secrets, .env.example unchanged"
ck ".env.example unchanged vs base branch task/T01-agents (absent from main)" git diff --quiet task/T01-agents -- .env.example
if [ -x .tools/pre-commit ]; then
  ck "pre-commit (secret scan etc.) passes on all files" .tools/pre-commit run --all-files
else
  bad "BLOCKED .tools/pre-commit not installed (run scripts/bootstrap-dev.sh)"
fi
ck "no key-like strings in T02 docs" bash -c "[ -s $SA ] && ! grep -rnE 'AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY' $SA $NM $ADRDIR | grep -q ."

echo "== TC-T02-30 C7 links resolve; markdown lint when available"
links_ok() { local f d l rc=0
  for f in "$SA" "$NM" "$ADRDIR"/ADR-000[1-6]-*.md "$ADRDIR/README.md"; do
    [ -s "$f" ] || { echo "missing $f"; rc=1; continue; }
    d="$(dirname "$f")"
    while IFS= read -r l; do
      [ -e "$d/$l" ] || { echo "$f: broken link $l"; rc=1; }
    done < <(grep -oE '\]\([^)#][^)]*\)' "$f" | sed -E 's/^\]\(//; s/\)$//; s/#.*//' | grep -vE '^(https?:|mailto:)')
  done; return "$rc"; }
ck "relative links in T02 docs resolve" links_ok
if command -v markdownlint >/dev/null 2>&1; then
  ck "markdownlint clean on T02 docs" markdownlint "$SA" "$NM" "$ADRDIR"/ADR-000[1-6]-*.md
else
  printf '  SKIP  markdownlint not installed (plan says "if available"; record in report)\n'
fi

echo
if [ "$fail" -eq 0 ]; then echo "ALL AUTOMATED CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit "$fail"
