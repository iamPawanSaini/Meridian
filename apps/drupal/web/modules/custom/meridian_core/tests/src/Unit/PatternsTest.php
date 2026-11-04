<?php

declare(strict_types=1);

namespace Drupal\Tests\meridian_core\Unit;

use Drupal\meridian_core\Validation\Patterns;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\TestCase;

/**
 * Each pattern of the data model accepts and rejects the right values.
 *
 * Covers TC-T09-08.
 */
#[Group('meridian_core')]
class PatternsTest extends TestCase {

  /**
   * Cases: pattern constant, accepted values, rejected values.
   *
   * @return array<string, array{0: string, 1: string[], 2: string[]}>
   *   The cases.
   */
  public static function patternCases(): array {
    return [
      'symbol' => [
        Patterns::SYMBOL,
        ['RELIANCE', 'M&M', 'BAJAJ-AUTO', 'NIFTY50', 'A', str_repeat('A', 20)],
        ['reliance', str_repeat('A', 21), '', 'A B', 'A.B', 'A_B', "RELIANCE\n"],
      ],
      'version label' => [
        Patterns::VERSION_LABEL,
        ['0.0.1', '1.2.3', '10.20.30'],
        ['1.2', '1.2.3.4', 'v1.2.3', '1.2.x', ' 1.2.3', '1.2.3 ', "1.2.3\n", ''],
      ],
      'model name' => [
        Patterns::MODEL_NAME,
        ['claude-sonnet-5-5', 'a', 'a' . str_repeat('b.', 31) . 'c', '0abc'],
        ['Claude', '.abc', '-abc', 'a' . str_repeat('b', 64), '', 'a b'],
      ],
      'rule id' => [
        Patterns::RULE_ID,
        ['R1_A', 'ABC', 'A' . str_repeat('B', 31), 'TREND-OK'],
        ['abc', 'A', 'A' . str_repeat('B', 32), '1ABC', ''],
      ],
      'uuid' => [
        Patterns::UUID,
        ['123e4567-e89b-42d3-a456-426614174000', '00000000-0000-4000-8000-000000000000'],
        ['123E4567-E89B-42D3-A456-426614174000', '123e4567e89b42d3a456426614174000', '123e4567-e89b-42d3-a456-42661417400', '123e4567-e89b-42d3-a456-4266141740000'],
      ],
      'payload hash' => [
        Patterns::PAYLOAD_HASH,
        [str_repeat('a', 64), str_repeat('0', 64), '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'],
        [str_repeat('A', 64), str_repeat('a', 63), str_repeat('a', 65), str_repeat('g', 64), str_repeat('a', 64) . "\n"],
      ],
      'date' => [
        Patterns::DATE_ONLY,
        ['2026-11-04', '2026-01-31', '2026-12-01'],
        ['2026-13-04', '2026-00-04', '2026-11-32', '2026-11-00', '2026-1-04', '26-11-04'],
      ],
      'decision external id' => [
        Patterns::EXTERNAL_ID_DECISION,
        ['dec-2026-11-04-RELIANCE-long', 'dec-2026-11-04-M&M-short'],
        ['dec-2026-11-04-RELIANCE-longg', 'dec-2026-11-04-RELIANCE-LONG', 'dec-2026-11-04-RELIANCE', 'dec-2026-13-04-RELIANCE-long', 'pos-2026-11-04-RELIANCE-long', 'DEC-2026-11-04-RELIANCE-long', "dec-2026-11-04-RELIANCE-long\n", 'dec-2026-11-04-RELIANCE-long-x'],
      ],
      'position external id' => [
        Patterns::EXTERNAL_ID_POSITION,
        ['pos-RELIANCE-short-2026-11-04', 'pos-M&M-long-2026-11-04'],
        ['pos-RELIANCE-flat-2026-11-04', 'pos-RELIANCE-short-2026-13-04', 'pos-RELIANCE-short', 'dec-RELIANCE-short-2026-11-04', "pos-RELIANCE-short-2026-11-04\n"],
      ],
      'daily run external id' => [
        Patterns::EXTERNAL_ID_DAILY_RUN,
        ['run-2026-11-04'],
        ['run-2026-13-04', 'run-2026-11-4', 'RUN-2026-11-04', 'run-2026-11-04-x', "run-2026-11-04\n"],
      ],
      'price snapshot external id' => [
        Patterns::EXTERNAL_ID_PRICE_SNAPSHOT,
        ['px-2026-11-04-RELIANCE', 'px-2026-11-04-NIFTY50'],
        ['px-2026-13-04-RELIANCE', 'px-2026-11-04', 'px-2026-11-04-reliance', "px-2026-11-04-RELIANCE\n"],
      ],
      'watchlist external id' => [
        Patterns::EXTERNAL_ID_WATCHLIST_ITEM,
        ['wl-RELIANCE', 'wl-M&M'],
        ['wl-reliance', 'wl-', 'WL-RELIANCE', 'wl-' . str_repeat('A', 21), "wl-RELIANCE\n"],
      ],
    ];
  }

  /**
   * Accepted and rejected values of every pattern.
   *
   * @param string $pattern
   *   The pattern.
   * @param string[] $accepted
   *   Values that must match.
   * @param string[] $rejected
   *   Values that must not match.
   */
  #[DataProvider('patternCases')]
  public function testAcceptsAndRejects(string $pattern, array $accepted, array $rejected): void {
    foreach ($accepted as $value) {
      $this->assertTrue(Patterns::matches($pattern, $value), "accepts '$value'");
    }
    foreach ($rejected as $value) {
      $this->assertFalse(Patterns::matches($pattern, $value), "rejects '" . addcslashes($value, "\n") . "'");
    }
  }

  /**
   * Values that are not strings never match.
   */
  public function testNonStringsNeverMatch(): void {
    foreach ([NULL, 5, 1.5, TRUE, [], new \stdClass()] as $value) {
      $this->assertFalse(Patterns::matches(Patterns::SYMBOL, $value));
    }
  }

  /**
   * Every bundle has its own external ID pattern.
   */
  public function testEveryBundleHasAnExternalIdPattern(): void {
    $samples = [
      'decision' => 'dec-2026-11-04-RELIANCE-long',
      'position' => 'pos-RELIANCE-long-2026-11-04',
      'daily_run' => 'run-2026-11-04',
      'price_snapshot' => 'px-2026-11-04-RELIANCE',
      'watchlist_item' => 'wl-RELIANCE',
    ];
    foreach ($samples as $bundle => $id) {
      foreach (Patterns::EXTERNAL_ID_BY_BUNDLE as $other => $pattern) {
        $this->assertSame($bundle === $other, Patterns::matches($pattern, $id), "$id against $other");
      }
    }
  }

}
