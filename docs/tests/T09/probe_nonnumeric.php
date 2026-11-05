<?php

declare(strict_types=1);

/**
 * @file
 * TC-T09-12 supplement: how does a non-numeric score validate? Read-only probe, no save.
 *
 * Run: ddev drush php:script docs/tests/T09/probe_nonnumeric.php
 */

use Drupal\node\Entity\Node;

$base = [
  'type' => 'decision',
  'title' => 'RELIANCE long 2026-11-03',
  'field_external_id' => 'dec-2026-11-03-RELIANCE-long',
  'field_trade_date' => '2026-11-03',
  'field_symbol' => 'RELIANCE',
  'field_mode' => 'long',
  'field_score' => '72.50',
  'field_pre_llm_action' => 'BUY',
  'field_action' => 'BUY',
  'field_vetoed' => 0,
  'field_rule_version' => '1.0.0',
  'field_prompt_version' => '1.0.0',
  'field_model_name' => 'claude-sonnet-5-5',
  'field_inputs_snapshot' => '{}',
  'field_raw_llm_output' => '{}',
  'field_close_price' => '2850.5000',
  'field_run' => 1,
  'field_source_version' => 1,
  'field_payload_hash' => str_repeat('a', 64),
];
$position = [
  'type' => 'position',
  'title' => 'RELIANCE long 2026-11-03',
  'field_external_id' => 'pos-RELIANCE-long-2026-11-03',
  'field_symbol' => 'RELIANCE',
  'field_mode' => 'long',
  'field_status' => 'open',
  'field_entry_date' => '2026-11-03',
  'field_entry_price' => '2850.5000',
  'field_stop_price' => '2800',
  'field_target_price' => '2950',
  'field_costs_total' => '0',
  'field_run' => 1,
  'field_decision' => 1,
  'field_source_version' => 1,
  'field_payload_hash' => str_repeat('a', 64),
];
foreach ([1.5, '1.5', 'abc', '2'] as $quantity) {
  $node = Node::create(['field_quantity' => $quantity] + $position);
  $out = [];
  foreach ($node->validate() as $v) {
    if (str_starts_with($v->getPropertyPath(), 'field_quantity')) {
      $out[] = $v->getPropertyPath() . ' [' . $v->getCode() . '] ' . strip_tags((string) $v->getMessage());
    }
  }
  printf("quantity %-6s => %d quantity violations: %s\n", var_export($quantity, TRUE), count($out), implode(' | ', $out));
}
foreach (['abc', '1e5', '', 'NaN', '50,5', ' 50', '5 0'] as $score) {
  $node = Node::create(['field_score' => $score] + $base);
  $out = [];
  foreach ($node->validate() as $v) {
    $out[] = $v->getPropertyPath() . ' [' . $v->getCode() . '] ' . $v->getMessage();
  }
  printf("score %-6s => %d violations: %s\n", var_export($score, TRUE), count($out), implode(' | ', $out));
}
