<?php

declare(strict_types=1);

namespace Drupal\Tests\meridian_core\Unit;

use Drupal\meridian_core\Validation\Decimals;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\TestCase;

/**
 * Exact comparison of decimals held as strings.
 */
#[Group('meridian_core')]
class DecimalsTest extends TestCase {

  /**
   * Comparison results for pairs of values.
   */
  public function testCompare(): void {
    $cases = [
      ['1', '2', -1], ['2', '1', 1], ['1', '1.0', 0], ['0.0001', '0', 1], ['-1', '1', -1], ['-2', '-1', -1],
      ['-1', '-2', 1], ['10', '9', 1], ['99999999999999.9999', '99999999999999.9998', 1], ['0', '-0', 0],
      ['2850.5000', '2850.5', 0], [1.5, '1.5', 0], [3, '2.9999', 1], ['0.10', '0.1', 0],
    ];
    foreach ($cases as [$a, $b, $expected]) {
      $this->assertSame($expected, Decimals::compare($a, $b), "$a <=> $b");
    }
  }

  /**
   * Values that are not numbers cannot be compared.
   */
  public function testNonNumbers(): void {
    $this->assertNull(Decimals::compare('abc', '1'));
    $this->assertNull(Decimals::compare('1', NULL));
    $this->assertNull(Decimals::normalize('1e5'));
    $this->assertNull(Decimals::normalize([]));
  }

  /**
   * Normalising removes leading and trailing zeros.
   */
  public function testNormalize(): void {
    $this->assertSame('7.5', Decimals::normalize('007.50'));
    $this->assertSame('0', Decimals::normalize('0.000'));
    $this->assertSame('-0.5', Decimals::normalize('-0.5'));
    $this->assertSame('12', Decimals::normalize(12));
    $this->assertSame('50.5', Decimals::normalize(50.5));
  }

}
