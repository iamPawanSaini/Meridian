<?php

declare(strict_types=1);

namespace Drupal\Tests\meridian_core\Kernel;

use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\RunTestsInSeparateProcesses;

/**
 * Every validation rule of the Price Snapshot bundle (TC-T09-23).
 */
#[Group('meridian_core')]
#[RunTestsInSeparateProcesses]
class PriceSnapshotValidationTest extends MeridianKernelTestBase {

  /**
   * Required fields, lists and the external ID.
   */
  public function testRequiredFieldsListsAndExternalId(): void {
    $this->assertValid($this->record('price_snapshot'), 'baseline');
    $required = ['title', 'field_external_id', 'field_trade_date', 'field_symbol', 'field_open', 'field_high',
      'field_low', 'field_close', 'field_volume', 'field_adjusted', 'field_source', 'field_source_version',
      'field_payload_hash',
    ];
    $cases = [];
    foreach ($required as $field) {
      $cases["$field missing"] = [[$field => NULL], [[$field, self::REQUIRED]]];
    }
    $cases['adjusted false'] = [['field_adjusted' => 0], []];
    $cases['adjusted true'] = [['field_adjusted' => 1], []];
    $cases['source stub'] = [['field_source' => 'stub'], []];
    $cases['source google'] = [['field_source' => 'google'], [['field_source', self::NOT_ALLOWED]]];
    $cases['external_id regex'] = [['field_external_id' => 'px-2026-13-03-RELIANCE'], [['field_external_id', 'meridian.pattern']]];
    $cases['trade_date differs from the id'] = [['field_trade_date' => '2026-11-02'], [['field_external_id', 'meridian.external_id_mismatch']]];
    $cases['symbol differs from the id'] = [['field_symbol' => 'TCS'], [['field_external_id', 'meridian.external_id_mismatch']]];
    $cases['symbol lowercase'] = [['field_symbol' => 'tcs'], [['field_symbol', 'meridian.pattern']]];
    $cases['source_version 0'] = [['field_source_version' => 0], [['field_source_version', self::TOO_LOW]]];
    $cases['payload_hash uppercase'] = [['field_payload_hash' => strtoupper($this->hash())], [['field_payload_hash', 'meridian.pattern']]];
    $this->runCases('price_snapshot', $cases);
  }

  /**
   * Prices, volume and the open-high-low-close ordering.
   */
  public function testPricesVolumeAndOrdering(): void {
    $scale = 'meridian.decimal_scale';
    $cases = [
      'open 0' => [['field_open' => '0'], [['field_open', self::TOO_LOW]]],
      'close 0' => [['field_close' => '0'], [['field_close', self::TOO_LOW]]],
      'low 0' => [['field_low' => '0'], [['field_low', self::TOO_LOW]]],
      'low above open' => [['field_low' => '101'], [['field_low', 'meridian.price_snapshot.low_above_open']]],
      'low above close' => [['field_close' => '94'], [['field_low', 'meridian.price_snapshot.low_above_close']]],
      'low equal to open and close' => [['field_open' => '95', 'field_close' => '95', 'field_high' => '95'], []],
      'high below open' => [['field_high' => '99'], [['field_high', 'meridian.price_snapshot.high_below_open']]],
      'high below low' => [['field_high' => '90'], [['field_high', 'meridian.price_snapshot.high_below_low']]],
      'high below close' => [['field_high' => '102', 'field_open' => '100', 'field_close' => '105'], [['field_high', 'meridian.price_snapshot.high_below_close']]],
      'high equal to the largest' => [['field_high' => '105'], []],
      'open with 5 decimals' => [['field_open' => '100.00001'], [['field_open', $scale]]],
      'high with 5 decimals' => [['field_high' => '110.00001'], [['field_high', $scale]]],
      'low with 5 decimals' => [['field_low' => '95.00001'], [['field_low', $scale]]],
      'close with 5 decimals' => [['field_close' => '105.00001'], [['field_close', $scale]]],
      'volume -1' => [['field_volume' => -1], [['field_volume', self::TOO_LOW]]],
      'volume 0' => [['field_volume' => 0], []],
      'volume above 2^31' => [['field_volume' => 3000000000], []],
      'open missing gives no ordering violation' => [['field_open' => NULL], [['field_open', self::REQUIRED]]],
    ];
    $this->runCases('price_snapshot', $cases);
  }

}
