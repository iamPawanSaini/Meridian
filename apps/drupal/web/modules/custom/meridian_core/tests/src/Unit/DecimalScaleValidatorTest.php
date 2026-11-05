<?php

declare(strict_types=1);

namespace Drupal\Tests\meridian_core\Unit;

use Drupal\meridian_core\Plugin\Validation\Constraint\MeridianDecimalScale;
use Drupal\meridian_core\Plugin\Validation\Constraint\MeridianDecimalScaleValidator;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\TestCase;

/**
 * The decimal scale rule: no rounding, no overflow of precision and scale.
 *
 * Covers TC-T09-09.
 */
#[Group('meridian_core')]
class DecimalScaleValidatorTest extends TestCase {

  use ValidatorHarnessTrait;

  /**
   * Runs the validator for a (5,2) field.
   *
   * @return string[]
   *   The violation codes.
   */
  protected function check(mixed $value, bool $integerDigits = TRUE): array {
    return $this->codes(new MeridianDecimalScaleValidator(), $value, new MeridianDecimalScale(precision: 5, scale: 2, integerDigits: $integerDigits));
  }

  /**
   * Too many fractional digits are rejected.
   */
  public function testRejectsTooManyFractionDigits(): void {
    foreach (['50.123', '0.001', '-0.001', '1.999', 50.123, '99.999'] as $value) {
      $this->assertSame([MeridianDecimalScale::CODE_SCALE], $this->check($value), (string) $value);
    }
  }

  /**
   * Too many integer digits are rejected when the check is on.
   */
  public function testRejectsTooManyIntegerDigits(): void {
    foreach (['1000', '1000.5', '-1000', '12345.67', 1000] as $value) {
      $this->assertSame([MeridianDecimalScale::CODE_PRECISION], $this->check($value), (string) $value);
    }
    $this->assertSame([], $this->check('1000', FALSE), 'fields with a maximum leave this to the range rule');
  }

  /**
   * Values that fit are accepted, in string, integer and float form.
   */
  public function testAcceptsValuesThatFit(): void {
    foreach (['0', '0.0', '0.00', '-0.01', '999.99', '-999.99', '100', '50.5', '50.500', '007.5', 0, 12, 50.5, '1.10'] as $value) {
      $this->assertSame([], $this->check($value), (string) $value);
    }
  }

  /**
   * Values that are not numbers and empty values add nothing.
   */
  public function testIgnoresNonNumbersAndEmptyValues(): void {
    foreach (['abc', '1e5', '1,5', ' 1', '', NULL, '--1'] as $value) {
      $this->assertSame([], $this->check($value), var_export($value, TRUE));
    }
  }

}
