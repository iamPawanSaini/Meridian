#!/usr/bin/env bash
# TC-T09-07, 11, 12, 55: mutation (sensitivity) checks. Throwaway, tester-owned.
#
# The mutations run in a COPY of apps/drupal inside the DDEV web container (/tmp/mut/drupal, not
# the repository). Production files are never edited. Usage:
#   docs/tests/T09/mutations.sh prepare            # copy apps/drupal into the container
#   docs/tests/T09/mutations.sh run NAME CLASS     # restore, mutate, run one Kernel class
# NAME is one of: score101 uniq immut status_daily vetoed_notreq analyst_raw nokey symbol21
# short2 nofield none. Exit status is that of PHPUnit: non-zero means the mutation was detected.
set -u
SRC=/var/www/html/apps/drupal
DST=${MUT_DST:-/tmp/mut/drupal}
MOD=web/modules/custom/meridian_core

x() { ddev exec "$1"; }

case "${1:-}" in
  prepare)
    x "rm -rf /tmp/mut && mkdir -p /tmp/mut && cp -a $SRC $DST && du -sh /tmp/mut"
    exit 0
    ;;
  run) ;;
  *)
    echo "usage: $0 prepare | run NAME CLASS" >&2
    exit 2
    ;;
esac

name=$2
class=$3
x "rm -rf $DST/config/sync $DST/$MOD && cp -a $SRC/config/sync $DST/config/sync && cp -a $SRC/$MOD $DST/$MOD"
case "$name" in
  none) ;;
  score101) x "sed -i 's/^  max: 100.0/  max: 101.0/' $DST/config/sync/field.field.node.decision.field_score.yml && grep -n 'max:' $DST/config/sync/field.field.node.decision.field_score.yml" ;;
  uniq) x "sed -i \"/\\['MeridianUniqueInBundle', NULL\\];/{/field_external_id/d}\" $DST/$MOD/src/Hook/FieldConstraintHooks.php && grep -n 'MeridianUniqueInBundle' $DST/$MOD/src/Hook/FieldConstraintHooks.php" ;;
  immut) x "sed -i \"/\\['field_external_id'\\]\\[\\] = \\['MeridianImmutable', NULL\\];/d\" $DST/$MOD/src/Hook/FieldConstraintHooks.php && grep -n 'MeridianImmutable' $DST/$MOD/src/Hook/FieldConstraintHooks.php" ;;
  status_daily) x "sed -i '/^third_party_settings:/,/^id:/{/^third_party_settings:/d;/^  meridian_core:/d;/^    allowed_values:/d;/^      - /d}' $DST/config/sync/field.field.node.daily_run.field_status.yml && grep -n 'third_party\\|allowed_values' $DST/config/sync/field.field.node.daily_run.field_status.yml; echo '(setting removed)'" ;;
  vetoed_notreq) x "sed -i 's/^required: true/required: false/' $DST/config/sync/field.field.node.decision.field_vetoed.yml && grep -n '^required' $DST/config/sync/field.field.node.decision.field_vetoed.yml" ;;
  analyst_raw) x "sed -i \"s/^  - 'view meridian inputs'/  - 'view meridian inputs'\\n  - 'view meridian raw llm output'/\" $DST/config/sync/user.role.analyst.yml && grep -n 'meridian' $DST/config/sync/user.role.analyst.yml" ;;
  nokey) x "sed -i 's/    if (!\$this->tableExists()) {/    return FALSE;\\n    if (!\$this->tableExists()) {/' $DST/$MOD/src/Schema/ExternalIdIndex.php && grep -n -B1 -A2 'return FALSE;' $DST/$MOD/src/Schema/ExternalIdIndex.php | head -12" ;;
  symbol21) x "sed -i 's/^  max_length: 20/  max_length: 21/' $DST/config/sync/field.storage.node.field_symbol.yml && grep -n max_length $DST/config/sync/field.storage.node.field_symbol.yml" ;;
  short2) x "sed -i '0,/^      value: short/s//      value: short2/' $DST/config/sync/field.storage.node.field_mode.yml && grep -n 'value: short' $DST/config/sync/field.storage.node.field_mode.yml" ;;
  nofield) x "rm $DST/config/sync/field.field.node.decision.field_score.yml && ls $DST/config/sync | grep -c 'field.field.node.decision'" ;;
  *) echo "unknown mutation $name" >&2; exit 2 ;;
esac
echo "== mutation $name, class $class"
x "set -o pipefail; cd $DST && vendor/bin/phpunit --testsuite kernel --filter $class 2>&1 | tail -60"
