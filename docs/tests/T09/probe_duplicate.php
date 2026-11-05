<?php

declare(strict_types=1);

/**
 * @file
 * TC-T09-31 supplement: the duplicate message must not name another record's data.
 *
 * Creates one Daily Run, validates a second with the same external ID, prints the messages and
 * deletes the first. Run on a throwaway install:
 *   ddev drush php:script docs/tests/T09/probe_duplicate.php
 */

use Drupal\node\Entity\Node;

$values = [
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
  'field_payload_hash' => str_repeat('a', 64),
];
$first = Node::create($values);
$first->save();
printf("first saved: nid %s\n", $first->id());
$second = Node::create(['title' => 'SECRET-OTHER-TITLE'] + $values);
foreach ($second->validate() as $violation) {
  printf("%s [%s] %s\n", $violation->getPropertyPath(), $violation->getCode(), strip_tags((string) $violation->getMessage()));
}
$first->delete();
printf("cleaned up\n");
