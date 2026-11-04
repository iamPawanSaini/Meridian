<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\meridian_core\Validation\Decimals;
use Drupal\meridian_core\Validation\FieldValidatorBase;
use Drupal\meridian_core\Validation\FieldValues;
use Symfony\Component\Validator\Constraint;
use Symfony\Component\Validator\Exception\UnexpectedTypeException;

/**
 * Validates MeridianDecimalScale.
 *
 * Trailing zeros do not count: 50.500 is the same number as 50.5, so storing it
 * loses nothing. Values that are not numbers are left to the Range rule.
 */
class MeridianDecimalScaleValidator extends FieldValidatorBase {

  /**
   * {@inheritdoc}
   */
  public function validate(mixed $value, Constraint $constraint): void {
    if (!$constraint instanceof MeridianDecimalScale) {
      throw new UnexpectedTypeException($constraint, MeridianDecimalScale::class);
    }
    foreach (FieldValues::of($value) as $delta => $item) {
      $number = Decimals::normalize($item);
      if ($number === NULL) {
        continue;
      }
      [$integer, $fraction] = array_pad(explode('.', ltrim($number, '-'), 2), 2, '');
      if (strlen($fraction) > $constraint->scale) {
        $this->report($value, $delta, 'The value has more than @scale decimal places.', ['@scale' => $constraint->scale], MeridianDecimalScale::CODE_SCALE);
      }
      elseif ($constraint->integerDigits && $integer !== '0' && strlen($integer) > $constraint->precision - $constraint->scale) {
        $this->report($value, $delta, 'The value has more than @digits digits before the decimal point.', ['@digits' => $constraint->precision - $constraint->scale], MeridianDecimalScale::CODE_PRECISION);
      }
    }
  }

}
