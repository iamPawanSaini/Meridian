<?php

declare(strict_types=1);

namespace Drupal\Tests\meridian_core\Kernel;

use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\RunTestsInSeparateProcesses;

/**
 * Every validation rule of the Daily Run bundle (TC-T09-21 and TC-T09-22).
 */
#[Group('meridian_core')]
#[RunTestsInSeparateProcesses]
class DailyRunValidationTest extends MeridianKernelTestBase {

  /**
   * Required fields, the status subset and the lists (TC-T09-21).
   */
  public function testRequiredFieldsAndLists(): void {
    $this->assertValid($this->record('daily_run'), 'baseline success run');
    $required = ['title', 'field_external_id', 'field_trade_date', 'field_run_id', 'field_attempt', 'field_status',
      'field_symbols_total', 'field_decisions_count', 'field_buy_count', 'field_veto_count', 'field_failure_count',
      'field_llm_cost_usd', 'field_rule_version', 'field_prompt_version', 'field_model_name', 'field_started_at',
      'field_source_version', 'field_payload_hash',
    ];
    $cases = [];
    foreach ($required as $field) {
      $cases["$field missing"] = [[$field => NULL], [[$field, self::REQUIRED]]];
    }
    foreach (['field_watchlist_source', 'field_finished_at', 'field_virtual_equity', 'field_skip_reason'] as $field) {
      $cases["optional $field empty"] = [[$field => NULL] + ($field === 'field_watchlist_source' ? ['field_status' => 'failed'] : []), []];
    }
    foreach (['open', 'closed'] as $status) {
      $cases["status $status"] = [['field_status' => $status], [['field_status', 'meridian.bundle_allowed_values']]];
    }
    $cases['status bogus'] = [['field_status' => 'bogus'], [['field_status', self::NOT_ALLOWED]]];
    $cases['status failed'] = [['field_status' => 'failed'], []];
    $cases['status skipped'] = [['field_status' => 'skipped', 'field_skip_reason' => 'holiday'], []];
    foreach (['drupal', 'snapshot', 'seed'] as $source) {
      $cases["watchlist_source $source"] = [['field_watchlist_source' => $source], []];
    }
    $cases['watchlist_source file'] = [['field_watchlist_source' => 'file'], [['field_watchlist_source', self::NOT_ALLOWED]]];
    $pattern = 'meridian.pattern';
    $cases['run_id uppercase'] = [['field_run_id' => strtoupper('123e4567-e89b-42d3-a456-426614174000')], [['field_run_id', $pattern]]];
    $cases['run_id without hyphens'] = [['field_run_id' => '123e4567e89b42d3a456426614174000'], [['field_run_id', $pattern]]];
    $cases['run_id 35 characters'] = [['field_run_id' => '123e4567-e89b-42d3-a456-42661417400'], [['field_run_id', $pattern]]];
    $cases['run_id 37 characters'] = [['field_run_id' => '123e4567-e89b-42d3-a456-4266141740000'], [['field_run_id', self::TOO_LONG]]];
    $cases['rule_version 1.2'] = [['field_rule_version' => '1.2'], [['field_rule_version', $pattern]]];
    $cases['prompt_version v1.2.3'] = [['field_prompt_version' => 'v1.2.3'], [['field_prompt_version', $pattern]]];
    $cases['model_name Claude'] = [['field_model_name' => 'Claude'], [['field_model_name', $pattern]]];
    $this->runCases('daily_run', $cases);
  }

  /**
   * Numeric ranges, counts and times (TC-T09-21).
   */
  public function testNumbersAndTimes(): void {
    $cases = [
      'attempt 0' => [['field_attempt' => 0], [['field_attempt', self::TOO_LOW]]],
      'attempt 1' => [['field_attempt' => 1], []],
      'symbols_total -1' => [['field_symbols_total' => -1], [['field_symbols_total', self::TOO_LOW]]],
      'symbols_total 0' => [['field_symbols_total' => 0], []],
      'symbols_total 50' => [['field_symbols_total' => 50], []],
      'symbols_total 51' => [['field_symbols_total' => 51], [['field_symbols_total', self::TOO_HIGH]]],
      'decisions_count -1' => [['field_decisions_count' => -1, 'field_buy_count' => 0], [['field_decisions_count', self::TOO_LOW]]],
      'decisions_count 0' => [['field_decisions_count' => 0, 'field_buy_count' => 0], []],
      'buy_count -1' => [['field_buy_count' => -1], [['field_buy_count', self::TOO_LOW]]],
      'veto_count -1' => [['field_veto_count' => -1], [['field_veto_count', self::TOO_LOW]]],
      'failure_count -1' => [['field_failure_count' => -1], [['field_failure_count', self::TOO_LOW]]],
      'veto_count 0' => [['field_veto_count' => 0, 'field_failure_count' => 0], []],
      'buy_count above decisions_count' => [['field_buy_count' => 3], [['field_buy_count', 'meridian.daily_run.buy_count_exceeds_decisions']]],
      'buy_count equal to decisions_count' => [['field_buy_count' => 2], []],
      'virtual_equity 0' => [['field_virtual_equity' => '0'], [['field_virtual_equity', self::TOO_LOW]]],
      'virtual_equity -1' => [['field_virtual_equity' => '-1'], [['field_virtual_equity', self::TOO_LOW]]],
      'virtual_equity 0.01' => [['field_virtual_equity' => '0.01'], []],
      'virtual_equity 3 decimals' => [['field_virtual_equity' => '10.001'], [['field_virtual_equity', 'meridian.decimal_scale']]],
      'llm_cost_usd -0.0001' => [['field_llm_cost_usd' => '-0.0001'], [['field_llm_cost_usd', self::TOO_LOW]]],
      'llm_cost_usd 0' => [['field_llm_cost_usd' => '0'], []],
      'llm_cost_usd 5 decimals' => [['field_llm_cost_usd' => '0.12345'], [['field_llm_cost_usd', 'meridian.decimal_scale']]],
      'finished_at before started_at' => [['field_finished_at' => 1793699999], [['field_finished_at', 'meridian.daily_run.finished_before_started']]],
      'finished_at equal to started_at' => [['field_finished_at' => 1793700000], []],
      'finished_at empty' => [['field_finished_at' => NULL], []],
      'external_id regex' => [['field_external_id' => 'run-2026-13-03'], [['field_external_id', 'meridian.pattern']]],
      'external_id date differs from trade_date' => [['field_trade_date' => '2026-11-02'], [['field_external_id', 'meridian.external_id_mismatch']]],
      'title is not checked' => [['title' => 'anything'], []],
    ];
    $this->runCases('daily_run', $cases);
  }

  /**
   * Skip reason and watchlist source by status (DN-4, TC-T09-22).
   */
  public function testConditionalFields(): void {
    $this->runCases('daily_run', [
      'skipped without reason' => [['field_status' => 'skipped'], [['field_skip_reason', 'meridian.daily_run.skip_reason_required']]],
      'skipped with reason and source' => [['field_status' => 'skipped', 'field_skip_reason' => 'holiday'], []],
      'skipped with reason and no source' => [['field_status' => 'skipped', 'field_skip_reason' => 'holiday', 'field_watchlist_source' => NULL], []],
      'skip_reason 255 characters' => [['field_status' => 'skipped', 'field_skip_reason' => str_repeat('a', 255)], []],
      'skip_reason 256 characters' => [['field_status' => 'skipped', 'field_skip_reason' => str_repeat('a', 256)], [['field_skip_reason', self::TOO_LONG]]],
      'success with reason' => [['field_skip_reason' => 'holiday'], [['field_skip_reason', 'meridian.daily_run.skip_reason_forbidden']]],
      'success without source' => [['field_watchlist_source' => NULL], [['field_watchlist_source', 'meridian.daily_run.watchlist_source_required']]],
      'success with source and no reason' => [[], []],
      'failed with stale_lock' => [['field_status' => 'failed', 'field_skip_reason' => 'stale_lock'], []],
      'failed without reason' => [['field_status' => 'failed'], []],
      'failed without source' => [['field_status' => 'failed', 'field_watchlist_source' => NULL], []],
      'invalid status gives no conditional violation' => [['field_status' => 'bogus', 'field_skip_reason' => 'x'], [['field_status', self::NOT_ALLOWED]]],
    ]);
  }

  /**
   * The date of a Daily Run or Price Snapshot may be in the future (Q-2).
   *
   * The plan applies the not-after-today rule to the Decision only. The test
   * records that behaviour so a change is a conscious one.
   */
  public function testFutureTradeDateIsNotRestricted(): void {
    $this->runCases('daily_run', [
      'future trade date' => [['field_trade_date' => '2026-12-31', 'field_external_id' => 'run-2026-12-31'], []],
    ]);
    $this->runCases('price_snapshot', [
      'future trade date' => [['field_trade_date' => '2026-12-31', 'field_external_id' => 'px-2026-12-31-RELIANCE'], []],
    ]);
  }

}
