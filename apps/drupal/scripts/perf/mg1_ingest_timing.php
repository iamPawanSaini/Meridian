<?php

declare(strict_types=1);

/**
 * @file
 * MG-1, NFR-04 entity-layer measurement (T09, docs/tasks/T09/decision-measurement-scope.md).
 *
 * Times 500 Decision creates and 500 Decision updates (a changed field and a new revision),
 * each pass in one database transaction, with validate() on every entity and zero violations
 * asserted. Five runs; each run starts with no Decisions (the deletion is not timed). One Daily
 * Run is created first and is not timed. Each Decision carries inputs_snapshot and
 * raw_llm_output of about 8 KB together, so 500 items are about 4 MB.
 *
 * It measures the entity layer only: no HTTP, OAuth, JSON decoding, hashing, reference
 * resolution or ingest lock. It uses no network and writes nothing to config/sync. Run it on a
 * throwaway install (ddev drupal-install --force restores the site):
 *
 *   ddev drush php:script apps/drupal/scripts/perf/mg1_ingest_timing.php
 *
 * With five runs the p95 is the slowest run, and the output says so.
 */

use Drupal\node\Entity\Node;

const MG1_ITEMS = 500;
const MG1_RUNS = 5;

if (extension_loaded('xdebug')) {
  fwrite(STDERR, "Xdebug is loaded. Turn it off (ddev xdebug off) and run again.\n");
  exit(1);
}

$storage = \Drupal::entityTypeManager()->getStorage('node');
$database = \Drupal::database();

// The script deletes every Decision between runs and at the end, so it refuses to touch a
// site that holds records.
$existing = $storage->getQuery()->accessCheck(FALSE)->condition('type', ['decision', 'daily_run'], 'IN')->count()->execute();
if ($existing > 0) {
  fwrite(STDERR, "Refusing to run: $existing decision or daily_run nodes exist. Use a throwaway install (ddev drupal-install --force).\n");
  exit(1);
}

/**
 * Builds a JSON object string of about the given size in bytes.
 */
$payload = static function (string $label, int $bytes): string {
  $items = [];
  $i = 0;
  while (strlen(json_encode($items)) < $bytes - 120) {
    $items['k' . $i++] = $label . ' ' . hash('sha256', $label . $i) . ' ' . str_repeat('x', 40);
  }
  return json_encode($items);
};

$check = static function ($entity, string $what): void {
  $violations = $entity->validate();
  if (count($violations) > 0) {
    foreach ($violations as $violation) {
      fwrite(STDERR, $what . ': ' . $violation->getPropertyPath() . ' ' . $violation->getMessage() . "\n");
    }
    exit(1);
  }
};

// One Daily Run that every Decision refers to (not timed).
$run = Node::create([
  'type' => 'daily_run',
  'title' => 'Run 2026-11-03',
  'field_external_id' => 'run-2026-11-03',
  'field_trade_date' => '2026-11-03',
  'field_run_id' => '123e4567-e89b-42d3-a456-426614174000',
  'field_attempt' => 1,
  'field_status' => 'success',
  'field_watchlist_source' => 'drupal',
  'field_symbols_total' => 50,
  'field_decisions_count' => 50,
  'field_buy_count' => 5,
  'field_veto_count' => 0,
  'field_failure_count' => 0,
  'field_llm_cost_usd' => '0.5',
  'field_rule_version' => '1.0.0',
  'field_prompt_version' => '1.0.0',
  'field_model_name' => 'claude-sonnet-5-5',
  'field_started_at' => 1793700000,
  'field_source_version' => 1,
  'field_payload_hash' => hash('sha256', 'run'),
]);
$check($run, 'daily_run');
$run->save();

$decision_values = static function (int $i) use ($run): array {
  $symbol = sprintf('SYM%03d', $i % 50);
  $date = gmdate('Y-m-d', strtotime('2026-01-01 +' . intdiv($i, 50) . ' days'));
  return [
    'type' => 'decision',
    'title' => "$symbol long $date",
    'field_external_id' => "dec-$date-$symbol-long",
    'field_trade_date' => $date,
    'field_symbol' => $symbol,
    'field_mode' => 'long',
    'field_score' => '72.50',
    'field_pre_llm_action' => 'BUY',
    'field_action' => 'BUY',
    'field_vetoed' => 0,
    'field_rule_hits' => ['TREND_OK', 'VOL_OK'],
    'field_rule_version' => '1.0.0',
    'field_prompt_version' => '1.0.0',
    'field_model_name' => 'claude-sonnet-5-5',
    'field_close_price' => '2850.5000',
    'field_run' => $run->id(),
    'field_source_version' => 1,
    'field_payload_hash' => hash('sha256', "decision $i"),
  ];
};

// The JSON text is built before the timers start: serialising is not entity-layer cost.
$inputs = [];
$raw = [];
$bytes = 0;
for ($i = 0; $i < MG1_ITEMS; $i++) {
  $inputs[$i] = $payload("inputs $i", 4600);
  $raw[$i] = $payload("raw $i", 3600);
  $bytes += strlen($inputs[$i]) + strlen($raw[$i]);
}

$delete_decisions = static function () use ($storage): void {
  $ids = $storage->getQuery()->accessCheck(FALSE)->condition('type', 'decision')->execute();
  foreach (array_chunk($ids, 100) as $chunk) {
    $storage->delete($storage->loadMultiple($chunk));
  }
};

$results = [];
for ($run_number = 1; $run_number <= MG1_RUNS; $run_number++) {
  $delete_decisions();

  $start = hrtime(TRUE);
  $transaction = $database->startTransaction();
  $ids = [];
  for ($i = 0; $i < MG1_ITEMS; $i++) {
    $node = Node::create($decision_values($i) + [
      'field_inputs_snapshot' => $inputs[$i],
      'field_raw_llm_output' => $raw[$i],
    ]);
    $check($node, "create $i");
    $node->save();
    $ids[] = $node->id();
  }
  unset($transaction);
  $create = (hrtime(TRUE) - $start) / 1e9;

  $start = hrtime(TRUE);
  $transaction = $database->startTransaction();
  $nodes = [];
  foreach (array_chunk($ids, 100) as $chunk) {
    $nodes += $storage->loadMultiple($chunk);
  }
  foreach ($nodes as $node) {
    $node->set('field_score', '80.25');
    $node->set('field_source_version', 2);
    $node->setNewRevision(TRUE);
    $check($node, 'update ' . $node->id());
    $node->save();
  }
  unset($transaction);
  $update = (hrtime(TRUE) - $start) / 1e9;

  $results[] = [$create, $update, $create + $update];
  printf("run %d: create %.2f s, update %.2f s, total %.2f s, violations 0\n", $run_number, $create, $update, $create + $update);
}
$delete_decisions();
$storage->delete([$run]);

$totals = array_column($results, 2);
sort($totals);
$creates = array_column($results, 0);
$updates = array_column($results, 1);
printf("\nitems per pass: %d, JSON payload per run: %.2f MB (inputs_snapshot plus raw_llm_output)\n", MG1_ITEMS, $bytes / 1048576);
printf("slowest create %.2f s, slowest update %.2f s\n", max($creates), max($updates));
printf("p95 of create plus update over %d runs: %.2f s (with 5 runs the p95 is the slowest run)\n", MG1_RUNS, end($totals));
printf("NFR-04 entity-layer limit used for the warning: 15 s (half of 30 s)\n");

$cpu = 'unknown';
foreach (@file('/proc/cpuinfo') ?: [] as $line) {
  if (str_starts_with($line, 'model name')) {
    $cpu = trim(explode(':', $line, 2)[1]);
    break;
  }
}
$ram = 'unknown';
foreach (@file('/proc/meminfo') ?: [] as $line) {
  if (str_starts_with($line, 'MemTotal')) {
    $ram = round((int) preg_replace('/\D/', '', $line) / 1048576, 1) . ' GiB';
    break;
  }
}
printf("\nenvironment: PHP %s, MariaDB %s, pcov %s, xdebug %s\n", PHP_VERSION, $database->query('SELECT VERSION()')->fetchField(), extension_loaded('pcov') ? 'loaded' : 'not loaded', extension_loaded('xdebug') ? 'loaded' : 'not loaded');
printf("host: %s; CPU %s; %d logical CPUs; RAM %s (WSL2 behind DDEV)\n", php_uname('s r'), $cpu, (int) trim((string) @shell_exec('nproc')), $ram);
