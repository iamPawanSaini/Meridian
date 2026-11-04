<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\meridian_core\Validation\FieldValidatorBase;
use Drupal\meridian_core\Validation\FieldValues;
use Symfony\Component\Validator\Constraint;
use Symfony\Component\Validator\Exception\UnexpectedTypeException;

/**
 * Validates MeridianNoDuplicateValues.
 *
 * One violation for the whole field, at the field path.
 */
class MeridianNoDuplicateValuesValidator extends FieldValidatorBase {

  /**
   * {@inheritdoc}
   */
  public function validate(mixed $value, Constraint $constraint): void {
    if (!$constraint instanceof MeridianNoDuplicateValues) {
      throw new UnexpectedTypeException($constraint, MeridianNoDuplicateValues::class);
    }
    $seen = [];
    foreach (FieldValues::of($value) as $item) {
      $key = is_scalar($item) ? (string) $item : serialize($item);
      if (isset($seen[$key])) {
        $this->reportField($constraint->message, ['@value' => $key], MeridianNoDuplicateValues::CODE);
        return;
      }
      $seen[$key] = TRUE;
    }
  }

}
