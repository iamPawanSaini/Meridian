<?php

declare(strict_types=1);

// phpcs:disable Drupal.Arrays.Array.LongLineDeclaration -- T09: one test case per line

namespace Drupal\Tests\meridian_core\Kernel;

use Drupal\Tests\meridian_core\Traits\FixedTime;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\RunTestsInSeparateProcesses;

/**
 * Every validation rule of the Decision bundle (TC-T09-10 to TC-T09-16).
 *
 * Each case changes one thing of the valid baseline and compares the exact
 * list of (property path, violation code) pairs.
 */
#[Group('meridian_core')]
#[RunTestsInSeparateProcesses]
class DecisionValidationTest extends MeridianKernelTestBase {

  /**
   * A JSON object of exactly the given size in bytes.
   */
  protected function json(int $bytes, string $filler = 'a'): string {
    $overhead = strlen('{"k":""}');
    $fill = $bytes - $overhead;
    $width = strlen($filler);
    return '{"k":"' . str_repeat($filler, intdiv($fill, $width)) . str_repeat('a', $fill % $width) . '"}';
  }

  /**
   * The baseline is valid and each required field is rejected when missing.
   */
  public function testBaselineAndRequiredFields(): void {
    $this->assertValid($this->record('decision'), 'baseline');
    $required = ['title', 'field_external_id', 'field_trade_date', 'field_symbol', 'field_mode', 'field_score',
      'field_pre_llm_action', 'field_action', 'field_vetoed', 'field_rule_version', 'field_prompt_version',
      'field_model_name', 'field_inputs_snapshot', 'field_raw_llm_output', 'field_close_price', 'field_run',
      'field_source_version', 'field_payload_hash',
    ];
    $cases = [];
    foreach ($required as $field) {
      $cases["$field missing"] = [[$field => NULL], [[$field, self::REQUIRED]]];
    }
    $cases['empty mode'] = [['field_mode' => ''], [['field_mode', self::REQUIRED]]];
    foreach (['field_veto_reason', 'field_rule_hits', 'field_llm_rationale'] as $field) {
      $cases["optional $field empty"] = [[$field => NULL], []];
    }
    $cases['vetoed false'] = [['field_vetoed' => 0], []];
    $cases['source_version 0'] = [['field_source_version' => 0], [['field_source_version', self::TOO_LOW]]];
    $cases['source_version -1'] = [['field_source_version' => -1], [['field_source_version', self::TOO_LOW]]];
    $cases['source_version 7'] = [['field_source_version' => 7], []];
    $this->runCases('decision', $cases);
  }

  /**
   * The mode, action and veto reason lists (AC2).
   */
  public function testEnumerations(): void {
    $cases = [];
    foreach (['long', 'short'] as $mode) {
      $cases["mode $mode"] = [[
        'field_mode' => $mode,
        'field_external_id' => "dec-2026-11-03-RELIANCE-$mode",
      ], [],
      ];
    }
    foreach (['longg', 'LONG', 'buy'] as $mode) {
      $cases["mode $mode"] = [['field_mode' => $mode], [['field_mode', self::NOT_ALLOWED]]];
    }
    foreach (['SELL', 'buy', 'HOLD'] as $action) {
      $cases["action $action"] = [['field_action' => $action], [['field_action', self::NOT_ALLOWED]]];
      $cases["pre_llm_action $action"] = [['field_pre_llm_action' => $action], [['field_pre_llm_action', self::NOT_ALLOWED]]];
    }
    $cases['action AVOID'] = [['field_action' => 'AVOID'], []];
    foreach (['llm_veto', 'malformed', 'empty', 'timeout', 'api_error', 'schema_violation', 'budget'] as $reason) {
      $cases["veto_reason $reason"] = [['field_vetoed' => 1, 'field_action' => 'AVOID', 'field_veto_reason' => $reason], []];
    }
    foreach (['other', 'LLM_VETO'] as $reason) {
      $cases["veto_reason $reason"] = [
        ['field_vetoed' => 1, 'field_action' => 'AVOID', 'field_veto_reason' => $reason],
        [['field_veto_reason', self::NOT_ALLOWED]],
      ];
    }
    $this->runCases('decision', $cases);
  }

  /**
   * Score boundaries and scale (AC2: score 0 to 100).
   */
  public function testScoreAndPrices(): void {
    $cases = [];
    foreach (['-0.01' => 'TOO_LOW', '100.01' => 'TOO_HIGH', '1000' => 'TOO_HIGH', '-1' => 'TOO_LOW'] as $score => $code) {
      $cases["score $score"] = [['field_score' => $score], [['field_score', constant("self::$code")]]];
    }
    $cases['score 50.123'] = [['field_score' => '50.123'], [['field_score', 'meridian.decimal_scale']]];
    foreach (['0', '0.00', '100', '100.00', '50.5'] as $score) {
      $cases["score $score"] = [['field_score' => $score], []];
    }
    $cases['close_price 0'] = [['field_close_price' => '0'], [['field_close_price', self::TOO_LOW]]];
    $cases['close_price -1'] = [['field_close_price' => '-1'], [['field_close_price', self::TOO_LOW]]];
    $cases['close_price 0.0001'] = [['field_close_price' => '0.0001'], []];
    $cases['close_price 5 decimals'] = [['field_close_price' => '1.00001'], [['field_close_price', 'meridian.decimal_scale']]];
    $cases['close_price 11 integer digits'] = [['field_close_price' => '12345678901.0000'], [['field_close_price', 'meridian.decimal_precision']]];
    $cases['close_price 10 integer digits'] = [['field_close_price' => '1234567890.1234'], []];
    $this->runCases('decision', $cases);
  }

  /**
   * The trade date is not after today in India Standard Time (TC-T09-13).
   */
  public function testTradeDateNotInTheFuture(): void {
    $date = static fn (string $d): array => [
      'field_trade_date' => $d,
      'field_external_id' => "dec-$d-RELIANCE-long",
    ];
    $future = [['field_trade_date', 'meridian.date_in_future']];
    // Fixed clock: 2026-11-04 12:00 UTC is 17:30 IST on 2026-11-04.
    $this->runCases('decision', [
      'tomorrow IST' => [$date('2026-11-05'), $future],
      'today IST' => [$date('2026-11-04'), []],
      'yesterday' => [$date('2026-11-03'), []],
    ]);
    // 23:59:59 IST on D (18:29:59 UTC) still accepts D and rejects D+1.
    FixedTime::$now = gmmktime(18, 29, 59, 11, 4, 2026);
    $this->runCases('decision', [
      '23:59:59 IST accepts D' => [$date('2026-11-04'), []],
      '23:59:59 IST rejects D+1' => [$date('2026-11-05'), $future],
    ]);
    // 00:00:00 IST on D+1 (18:30:00 UTC) accepts D+1 and rejects D+2.
    FixedTime::$now = gmmktime(18, 30, 0, 11, 4, 2026);
    $this->runCases('decision', [
      '00:00:00 IST accepts D+1' => [$date('2026-11-05'), []],
      '00:00:00 IST rejects D+2' => [$date('2026-11-06'), $future],
    ]);
    // A malformed date is rejected by the core date rules, which report it
    // twice (the stored value and the computed date), both without a code. No
    // Meridian rule adds a third violation.
    $this->assertViolations(
      $this->record('decision', ['field_trade_date' => '2026-13-45']),
      [['field_trade_date', ''], ['field_trade_date', '']],
      'malformed date',
    );
  }

  /**
   * Cross-field rules of action and veto (TC-T09-14).
   */
  public function testActionAndVetoRules(): void {
    $this->runCases('decision', [
      'BUY with pre AVOID' => [
        ['field_pre_llm_action' => 'AVOID'],
        [['field_action', 'meridian.decision.buy_requires_pre_buy']],
      ],
      'BUY with vetoed' => [
        ['field_vetoed' => 1, 'field_veto_reason' => 'llm_veto'],
        [['field_action', 'meridian.decision.buy_vetoed']],
      ],
      'vetoed with pre AVOID' => [
        ['field_pre_llm_action' => 'AVOID', 'field_action' => 'AVOID', 'field_vetoed' => 1, 'field_veto_reason' => 'llm_veto'],
        [['field_vetoed', 'meridian.decision.veto_requires_pre_buy']],
      ],
      'vetoed without reason' => [
        ['field_action' => 'AVOID', 'field_vetoed' => 1],
        [['field_veto_reason', 'meridian.decision.veto_reason_required']],
      ],
      'reason without veto' => [
        ['field_veto_reason' => 'llm_veto'],
        [['field_veto_reason', 'meridian.decision.veto_reason_forbidden']],
      ],
      'accepted: pre BUY, BUY, not vetoed' => [[], []],
      'accepted: pre BUY, AVOID, vetoed with reason' => [
        ['field_action' => 'AVOID', 'field_vetoed' => 1, 'field_veto_reason' => 'timeout'],
        [],
      ],
      'accepted: pre AVOID, AVOID' => [['field_pre_llm_action' => 'AVOID', 'field_action' => 'AVOID'], []],
      'accepted: pre BUY, AVOID, not vetoed' => [['field_action' => 'AVOID'], []],
      'invalid pre_llm_action gives only the list violation' => [
        ['field_pre_llm_action' => 'SELL'],
        [['field_pre_llm_action', self::NOT_ALLOWED]],
      ],
      'invalid action gives only the list violation' => [
        ['field_action' => 'SELL', 'field_vetoed' => 1, 'field_veto_reason' => 'llm_veto'],
        [['field_action', self::NOT_ALLOWED]],
      ],
    ]);
  }

  /**
   * Text, JSON, rule hits, version and length rules (TC-T09-15).
   */
  public function testTextAndDocumentRules(): void {
    $euro = '€';
    $pattern = 'meridian.pattern';
    $rules = array_map(static fn (int $i): string => sprintf('R%02d', $i), range(1, 51));
    $cases = [
      'rule_hits bad item' => [['field_rule_hits' => ['lower']], [['field_rule_hits.0', $pattern]]],
      'rule_hits bad item among valid ones' => [
        ['field_rule_hits' => ['TREND_OK', 'bad', 'VOL_OK']],
        [['field_rule_hits.1', $pattern]],
      ],
      'rule_hits 50 items' => [['field_rule_hits' => array_slice($rules, 0, 50)], []],
      'rule_hits 51 items' => [['field_rule_hits' => $rules], [['field_rule_hits', self::TOO_MANY]]],
      'rule_hits 33 characters' => [['field_rule_hits' => ['R' . str_repeat('A', 32)]], [['field_rule_hits.0', self::TOO_LONG]]],
      'rule_version 1.2' => [['field_rule_version' => '1.2'], [['field_rule_version', $pattern]]],
      'rule_version v1.2.3' => [['field_rule_version' => 'v1.2.3'], [['field_rule_version', $pattern]]],
      'rule_version 10.20.30' => [['field_rule_version' => '10.20.30'], []],
      'prompt_version 1.2' => [['field_prompt_version' => '1.2'], [['field_prompt_version', $pattern]]],
      'prompt_version 1.2.3.4' => [['field_prompt_version' => '1.2.3.4'], [['field_prompt_version', $pattern]]],
      'model_name Claude' => [['field_model_name' => 'Claude'], [['field_model_name', $pattern]]],
      'model_name 64 characters' => [['field_model_name' => 'a' . str_repeat('b', 63)], []],
      'model_name 65 characters' => [['field_model_name' => 'a' . str_repeat('b', 64)], [['field_model_name', self::TOO_LONG]]],
      'inputs_snapshot invalid JSON' => [['field_inputs_snapshot' => '{'], [['field_inputs_snapshot', 'meridian.json_invalid']]],
      'inputs_snapshot array' => [['field_inputs_snapshot' => '[1]'], [['field_inputs_snapshot', 'meridian.json_not_object']]],
      'inputs_snapshot string' => [['field_inputs_snapshot' => '"x"'], [['field_inputs_snapshot', 'meridian.json_not_object']]],
      'inputs_snapshot number' => [['field_inputs_snapshot' => '5'], [['field_inputs_snapshot', 'meridian.json_not_object']]],
      'inputs_snapshot null' => [['field_inputs_snapshot' => 'null'], [['field_inputs_snapshot', 'meridian.json_not_object']]],
      'inputs_snapshot empty object' => [['field_inputs_snapshot' => '{}'], []],
      'inputs_snapshot 65536 bytes' => [['field_inputs_snapshot' => $this->json(65536)], []],
      'inputs_snapshot 65537 bytes' => [['field_inputs_snapshot' => $this->json(65537)], [['field_inputs_snapshot', 'meridian.json_too_large']]],
      'inputs_snapshot multibyte at 65536 bytes' => [['field_inputs_snapshot' => $this->json(65536, $euro)], []],
      'inputs_snapshot multibyte at 65537 bytes' => [['field_inputs_snapshot' => $this->json(65537, $euro)], [['field_inputs_snapshot', 'meridian.json_too_large']]],
      'raw_llm_output invalid JSON' => [['field_raw_llm_output' => 'not json'], [['field_raw_llm_output', 'meridian.json_invalid']]],
      'raw_llm_output array' => [['field_raw_llm_output' => '[]'], [['field_raw_llm_output', 'meridian.json_not_object']]],
      'raw_llm_output 32768 bytes' => [['field_raw_llm_output' => $this->json(32768)], []],
      'raw_llm_output 32769 bytes' => [['field_raw_llm_output' => $this->json(32769)], [['field_raw_llm_output', 'meridian.json_too_large']]],
      'raw_llm_output multibyte at 32768 bytes' => [['field_raw_llm_output' => $this->json(32768, $euro)], []],
      'raw_llm_output multibyte at 32769 bytes' => [['field_raw_llm_output' => $this->json(32769, $euro)], [['field_raw_llm_output', 'meridian.json_too_large']]],
      'raw_llm_output not_called' => [['field_raw_llm_output' => '{"status":"not_called"}'], []],
      'llm_rationale 2000 characters' => [['field_llm_rationale' => str_repeat('a', 2000)], []],
      'llm_rationale 2000 multibyte characters' => [['field_llm_rationale' => str_repeat($euro, 2000)], []],
      'llm_rationale 2001 characters' => [['field_llm_rationale' => str_repeat('a', 2001)], [['field_llm_rationale', 'meridian.max_length']]],
      'title 255' => [['title' => str_repeat('a', 255)], []],
      'title 256' => [['title' => str_repeat('a', 256)], [['title', self::TOO_LONG]]],
      'payload_hash uppercase' => [['field_payload_hash' => strtoupper($this->hash())], [['field_payload_hash', $pattern]]],
      'payload_hash 63 characters' => [['field_payload_hash' => substr($this->hash(), 1)], [['field_payload_hash', $pattern]]],
      'payload_hash 65 characters' => [['field_payload_hash' => $this->hash() . 'a'], [['field_payload_hash', self::TOO_LONG]]],
      'symbol lowercase' => [['field_symbol' => 'reliance'], [['field_symbol', $pattern]]],
      'symbol 21 characters' => [['field_symbol' => str_repeat('A', 21)], [['field_symbol', self::TOO_LONG]]],
      'symbol with ampersand' => [['field_symbol' => 'M&M', 'field_external_id' => 'dec-2026-11-03-M&M-long'], []],
    ];
    $this->runCases('decision', $cases);
  }

  /**
   * The external ID rules: pattern and equality with the own fields (DN-5).
   */
  public function testExternalId(): void {
    $mismatch = [['field_external_id', 'meridian.external_id_mismatch']];
    $pattern = [['field_external_id', 'meridian.pattern']];
    $this->runCases('decision', [
      'id with mode longg' => [['field_external_id' => 'dec-2026-11-03-RELIANCE-longg'], $pattern],
      'id with LONG' => [['field_external_id' => 'dec-2026-11-03-RELIANCE-LONG'], $pattern],
      'id without mode' => [['field_external_id' => 'dec-2026-11-03-RELIANCE'], $pattern],
      'id with month 13' => [['field_external_id' => 'dec-2026-13-03-RELIANCE-long'], $pattern],
      'id with wrong prefix' => [['field_external_id' => 'pos-2026-11-03-RELIANCE-long'], $pattern],
      'id with uppercase prefix' => [['field_external_id' => 'DEC-2026-11-03-RELIANCE-long'], $pattern],
      'id with trailing newline' => [['field_external_id' => "dec-2026-11-03-RELIANCE-long\n"], $pattern],
      'id of 65 characters' => [['field_external_id' => str_repeat('a', 65)], [['field_external_id', self::TOO_LONG]]],
      'trade_date differs from the id' => [['field_trade_date' => '2026-11-02'], $mismatch],
      'symbol differs from the id' => [['field_symbol' => 'TCS'], $mismatch],
      'mode differs from the id' => [['field_mode' => 'short'], $mismatch],
      'title is not checked' => [['title' => 'anything'], []],
      'invalid symbol gives no mismatch' => [['field_symbol' => 'bad'], [['field_symbol', 'meridian.pattern']]],
      'invalid mode gives no mismatch' => [['field_mode' => 'longg'], [['field_mode', self::NOT_ALLOWED]]],
    ]);
  }

  /**
   * The run reference (TC-T09-16).
   */
  public function testRunReference(): void {
    $price = $this->record('price_snapshot');
    $price->save();
    $this->runCases('decision', [
      'run is a daily run' => [[], []],
      'run does not exist' => [['field_run' => 99999], [['field_run', '']]],
      'run is another bundle' => [['field_run' => $price->id()], [['field_run', '']]],
    ]);
  }

}
