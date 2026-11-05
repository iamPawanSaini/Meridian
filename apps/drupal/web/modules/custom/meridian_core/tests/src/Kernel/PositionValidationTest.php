<?php

declare(strict_types=1);

namespace Drupal\Tests\meridian_core\Kernel;

use Drupal\node\NodeInterface;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\RunTestsInSeparateProcesses;

/**
 * Every validation rule of the Position bundle (TC-T09-17 to TC-T09-20).
 */
#[Group('meridian_core')]
#[RunTestsInSeparateProcesses]
class PositionValidationTest extends MeridianKernelTestBase {

  /**
   * The values that make the baseline Position a complete closed one.
   */
  protected const CLOSED = [
    'field_status' => 'closed',
    'field_exit_date' => '2026-11-10',
    'field_exit_price' => '2900.0000',
    'field_exit_reason' => 'target',
    'field_realised_pnl' => '490.00',
  ];

  /**
   * Saves a Decision with changed values (a bare save) and returns it.
   *
   * @param array<string, mixed> $changes
   *   Field values that replace the baseline Decision.
   */
  protected function saveDecision(array $changes): NodeInterface {
    $decision = $this->record('decision', $changes);
    $decision->save();
    return $decision;
  }

  /**
   * A short Position needs a short Decision and a time stop date.
   *
   * @return array<string, mixed>
   *   Field values of a valid short open Position.
   */
  protected function shortValues(): array {
    $short = $this->saveDecision(['field_mode' => 'short', 'field_external_id' => 'dec-2026-11-03-RELIANCE-short']);
    return [
      'field_mode' => 'short',
      'field_external_id' => 'pos-RELIANCE-short-2026-11-03',
      'field_decision' => $short->id(),
      'field_time_stop_date' => '2026-11-10',
    ];
  }

  /**
   * The baseline is valid, required fields and bundle statuses (TC-T09-17).
   */
  public function testBaselineRequiredFieldsAndStatus(): void {
    $this->assertValid($this->record('position'), 'baseline open long');
    $this->assertValid($this->record('position', self::CLOSED), 'baseline closed long');
    $cases = [];
    $required = ['title', 'field_external_id', 'field_symbol', 'field_mode', 'field_status', 'field_entry_date',
      'field_entry_price', 'field_quantity', 'field_stop_price', 'field_target_price', 'field_costs_total',
      'field_run', 'field_decision', 'field_source_version', 'field_payload_hash',
    ];
    foreach ($required as $field) {
      $cases["$field missing"] = [[$field => NULL], [[$field, self::REQUIRED]]];
    }
    foreach (['success', 'skipped', 'failed'] as $status) {
      $cases["status $status"] = [['field_status' => $status], [['field_status', 'meridian.bundle_allowed_values']]];
    }
    $cases['status bogus'] = [['field_status' => 'bogus'], [['field_status', self::NOT_ALLOWED]]];
    $cases['status open'] = [['field_status' => 'open'], []];
    $cases['exit_reason manual'] = [['field_exit_reason' => 'manual'] + self::CLOSED, [['field_exit_reason', self::NOT_ALLOWED]]];
    foreach (['stop', 'gap_stop', 'target', 'time_stop'] as $reason) {
      $cases["exit_reason $reason"] = [['field_exit_reason' => $reason] + self::CLOSED, []];
    }
    $cases['mode longg'] = [['field_mode' => 'longg'], [['field_mode', self::NOT_ALLOWED]]];
    $this->runCases('position', $cases);
  }

  /**
   * Numeric ranges and the scale of every decimal (TC-T09-17).
   */
  public function testNumbers(): void {
    $scale = 'meridian.decimal_scale';
    $this->runCases('position', [
      'entry_price 0' => [['field_entry_price' => '0'], [['field_entry_price', self::TOO_LOW]]],
      'entry_price 0.0002' => [['field_entry_price' => '0.0002', 'field_stop_price' => '0.0001', 'field_target_price' => '0.0003'], []],
      'entry_price 5 decimals' => [
        ['field_entry_price' => '1.00001', 'field_stop_price' => '0.5', 'field_target_price' => '2'],
        [['field_entry_price', $scale]],
      ],
      'stop_price 5 decimals' => [['field_stop_price' => '2800.00001'], [['field_stop_price', $scale]]],
      'target_price 5 decimals' => [['field_target_price' => '2950.00001'], [['field_target_price', $scale]]],
      'exit_price 0' => [['field_exit_price' => '0'] + self::CLOSED, [['field_exit_price', self::TOO_LOW]]],
      'exit_price 5 decimals' => [['field_exit_price' => '2900.00001'] + self::CLOSED, [['field_exit_price', $scale]]],
      'last_mark_price 0' => [['field_last_mark_price' => '0'], [['field_last_mark_price', self::TOO_LOW]]],
      'last_mark_price 0.0001' => [['field_last_mark_price' => '0.0001'], []],
      'last_mark_price 5 decimals' => [['field_last_mark_price' => '2900.00001'], [['field_last_mark_price', $scale]]],
      'quantity 0' => [['field_quantity' => 0], [['field_quantity', self::TOO_LOW]]],
      'quantity -1' => [['field_quantity' => -1], [['field_quantity', self::TOO_LOW]]],
      'quantity 1' => [['field_quantity' => 1], []],
      'costs_total -0.01' => [['field_costs_total' => '-0.01'], [['field_costs_total', self::TOO_LOW]]],
      'costs_total 0' => [['field_costs_total' => '0'], []],
      'costs_total 3 decimals' => [['field_costs_total' => '1.234'], [['field_costs_total', $scale]]],
      'realised_pnl negative' => [['field_realised_pnl' => '-490.00'] + self::CLOSED, []],
      'realised_pnl 3 decimals' => [['field_realised_pnl' => '490.001'] + self::CLOSED, [['field_realised_pnl', $scale]]],
      'unrealised_pnl negative' => [['field_unrealised_pnl' => '-10.50'], []],
      'unrealised_pnl 3 decimals' => [['field_unrealised_pnl' => '10.501'], [['field_unrealised_pnl', $scale]]],
      'r_multiple 100.001' => [['field_r_multiple' => '100.001'], [['field_r_multiple', self::TOO_HIGH]]],
      'r_multiple -100.001' => [['field_r_multiple' => '-100.001'], [['field_r_multiple', self::TOO_LOW]]],
      'r_multiple 100' => [['field_r_multiple' => '100'], []],
      'r_multiple -100' => [['field_r_multiple' => '-100'], []],
      'r_multiple 4 decimals' => [['field_r_multiple' => '1.2345'], [['field_r_multiple', $scale]]],
    ]);
  }

  /**
   * Price ordering and the time stop by mode (TC-T09-18).
   */
  public function testPriceOrderingAndTimeStop(): void {
    $stop = 'meridian.position.stop_not_below_entry';
    $target = 'meridian.position.target_not_above_entry';
    $short = $this->shortValues();
    $this->runCases('position', [
      'stop_price 0' => [['field_stop_price' => '0'], [['field_stop_price', self::TOO_LOW]]],
      'stop equal to entry' => [['field_stop_price' => '2850.5000'], [['field_stop_price', $stop]]],
      'stop above entry' => [['field_stop_price' => '2900'], [['field_stop_price', $stop]]],
      'stop below entry' => [['field_stop_price' => '2850.4999'], []],
      'target equal to entry' => [['field_target_price' => '2850.5'], [['field_target_price', $target]]],
      'target below entry' => [['field_target_price' => '2000'], [['field_target_price', $target]]],
      'target above entry' => [['field_target_price' => '2850.5001'], []],
      'entry price missing gives no ordering violation' => [['field_entry_price' => NULL], [['field_entry_price', self::REQUIRED]]],
      'entry price 0 gives no ordering violation' => [['field_entry_price' => '0'], [['field_entry_price', self::TOO_LOW]]],
      'short is valid' => [$short + [], []],
      'short without time stop' => [['field_time_stop_date' => NULL] + $short, [['field_time_stop_date', 'meridian.position.time_stop_required']]],
      'short time stop on entry date' => [['field_time_stop_date' => '2026-11-03'] + $short, [['field_time_stop_date', 'meridian.position.time_stop_not_after_entry']]],
      'short time stop before entry date' => [['field_time_stop_date' => '2026-11-02'] + $short, [['field_time_stop_date', 'meridian.position.time_stop_not_after_entry']]],
      'short time stop after entry date' => [['field_time_stop_date' => '2026-11-04'] + $short, []],
      'long with time stop' => [['field_time_stop_date' => '2026-11-10'], [['field_time_stop_date', 'meridian.position.time_stop_forbidden']]],
      'long without time stop' => [[], []],
    ]);
  }

  /**
   * Open and closed positions (DN-4) and the dates (TC-T09-19).
   */
  public function testOpenAndClosedFields(): void {
    $required = 'meridian.position.exit_field_required';
    $forbidden = 'meridian.position.exit_field_forbidden';
    $cases = [];
    foreach (['field_exit_date', 'field_exit_price', 'field_exit_reason', 'field_realised_pnl'] as $field) {
      $cases["closed without $field"] = [[$field => NULL] + self::CLOSED, [[$field, $required]]];
      $cases["open with $field"] = [[$field => self::CLOSED[$field]], [[$field, $forbidden]]];
    }
    $cases['closed with unrealised_pnl'] = [
      ['field_unrealised_pnl' => '5.00'] + self::CLOSED,
      [['field_unrealised_pnl', 'meridian.position.unrealised_pnl_forbidden']],
    ];
    $cases['closed complete'] = [self::CLOSED, []];
    $cases['closed with a last mark'] = [['field_last_mark_price' => '2890', 'field_last_mark_date' => '2026-11-09'] + self::CLOSED, []];
    $cases['open with all mark fields'] = [
      ['field_unrealised_pnl' => '5.00', 'field_last_mark_price' => '2890', 'field_last_mark_date' => '2026-11-04'],
      [],
    ];
    $cases['open with none'] = [[], []];
    $cases['exit_date on entry date'] = [['field_exit_date' => '2026-11-03'] + self::CLOSED, [['field_exit_date', 'meridian.position.exit_not_after_entry']]];
    $cases['exit_date before entry date'] = [['field_exit_date' => '2026-11-02'] + self::CLOSED, [['field_exit_date', 'meridian.position.exit_not_after_entry']]];
    $cases['exit_date after entry date'] = [['field_exit_date' => '2026-11-04'] + self::CLOSED, []];
    $cases['last_mark_date before entry'] = [['field_last_mark_date' => '2026-11-02'], [['field_last_mark_date', 'meridian.position.mark_before_entry']]];
    $cases['last_mark_date on entry'] = [['field_last_mark_date' => '2026-11-03'], []];
    $cases['invalid status gives no conditional violation'] = [['field_status' => 'bogus', 'field_exit_date' => '2026-11-10'], [['field_status', self::NOT_ALLOWED]]];
    $this->runCases('position', $cases);
  }

  /**
   * The external ID rules of a Position (DN-5).
   */
  public function testExternalId(): void {
    $mismatch = [['field_external_id', 'meridian.external_id_mismatch']];
    $tcs = $this->saveDecision(['field_external_id' => 'dec-2026-11-03-TCS-long', 'field_symbol' => 'TCS']);
    $this->runCases('position', [
      'id with mode longg' => [['field_external_id' => 'pos-RELIANCE-longg-2026-11-03'], [['field_external_id', 'meridian.pattern']]],
      'id with wrong prefix' => [['field_external_id' => 'dec-RELIANCE-long-2026-11-03'], [['field_external_id', 'meridian.pattern']]],
      'symbol differs' => [['field_symbol' => 'TCS', 'field_decision' => $tcs->id()], $mismatch],
      'entry_date differs' => [['field_entry_date' => '2026-11-04'], $mismatch],
      'mode differs' => [['field_mode' => 'short', 'field_time_stop_date' => '2026-11-10'], array_merge($mismatch, [['field_decision', 'meridian.position.decision_mode_mismatch']])],
      'title is not checked' => [['title' => 'anything'], []],
    ]);
  }

  /**
   * The run and decision references and the DN-6 conditions (TC-T09-20).
   */
  public function testReferencesAndDecision(): void {
    $price = $this->record('price_snapshot');
    $price->save();
    $avoid = $this->saveDecision(['field_external_id' => 'dec-2026-11-02-RELIANCE-long', 'field_trade_date' => '2026-11-02', 'field_pre_llm_action' => 'AVOID', 'field_action' => 'AVOID']);
    $other_symbol = $this->saveDecision(['field_external_id' => 'dec-2026-11-03-TCS-long', 'field_symbol' => 'TCS']);
    $other_mode = $this->saveDecision(['field_external_id' => 'dec-2026-11-03-RELIANCE-short', 'field_mode' => 'short']);
    $after = $this->saveDecision(['field_external_id' => 'dec-2026-11-04-RELIANCE-long', 'field_trade_date' => '2026-11-04']);
    $earlier = $this->saveDecision(['field_external_id' => 'dec-2026-10-30-RELIANCE-long', 'field_trade_date' => '2026-10-30']);
    $unsaved = fn (array $changes): NodeInterface => $this->record('decision', $changes + ['field_external_id' => 'dec-2026-10-29-RELIANCE-long', 'field_trade_date' => '2026-10-29']);
    $this->runCases('position', [
      'run is another bundle' => [['field_run' => $price->id()], [['field_run', '']]],
      'run does not exist' => [['field_run' => 99999], [['field_run', '']]],
      'run is a decision' => [['field_run' => $this->referenceDecision()->id()], [['field_run', '']]],
      'decision is another bundle' => [['field_decision' => $price->id()], [['field_decision', '']]],
      'decision does not exist' => [['field_decision' => 99999], [['field_decision', '']]],
      'decision is a daily run' => [['field_decision' => $this->referenceRun()->id()], [['field_decision', '']]],
      'decision with action AVOID' => [['field_decision' => $avoid->id()], [['field_decision', 'meridian.position.decision_not_buy']]],
      'decision for another symbol' => [['field_decision' => $other_symbol->id()], [['field_decision', 'meridian.position.decision_symbol_mismatch']]],
      'decision with another mode' => [['field_decision' => $other_mode->id()], [['field_decision', 'meridian.position.decision_mode_mismatch']]],
      'decision dated after entry' => [['field_decision' => $after->id()], [['field_decision', 'meridian.position.decision_after_entry']]],
      'decision dated on entry' => [[], []],
      'decision dated earlier' => [['field_decision' => $earlier->id()], []],
    ]);
    // An unsaved Decision is read through the reference item (T10 attaches the
    // Decision of the same batch before it validates the Position).
    $cases = [
      'unsaved valid decision' => [$unsaved([]), []],
      'unsaved decision with action AVOID' => [$unsaved(['field_pre_llm_action' => 'AVOID', 'field_action' => 'AVOID']), [['field_decision', 'meridian.position.decision_not_buy']]],
      'unsaved decision for another symbol' => [$unsaved(['field_symbol' => 'TCS']), [['field_decision', 'meridian.position.decision_symbol_mismatch']]],
      'unsaved decision with another mode' => [$unsaved(['field_mode' => 'short']), [['field_decision', 'meridian.position.decision_mode_mismatch']]],
      'unsaved decision dated after entry' => [$unsaved(['field_trade_date' => '2026-11-04']), [['field_decision', 'meridian.position.decision_after_entry']]],
    ];
    foreach ($cases as $label => [$decision, $expected]) {
      $position = $this->record('position', ['field_decision' => NULL]);
      $position->get('field_decision')->entity = $decision;
      $this->assertViolations($position, $expected, 'position: ' . $label);
    }
  }

}
