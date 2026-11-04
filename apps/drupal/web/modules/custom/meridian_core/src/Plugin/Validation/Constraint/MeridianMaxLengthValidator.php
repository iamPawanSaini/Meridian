<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\meridian_core\Validation\FieldValidatorBase;
use Drupal\meridian_core\Validation\FieldValues;
use Symfony\Component\Validator\Constraint;
use Symfony\Component\Validator\Exception\UnexpectedTypeException;

/**
 * Validates MeridianMaxLength.
 */
class MeridianMaxLengthValidator extends FieldValidatorBase {

  /**
   * {@inheritdoc}
   */
  public function validate(mixed $value, Constraint $constraint): void {
    if (!$constraint instanceof MeridianMaxLength) {
      throw new UnexpectedTypeException($constraint, MeridianMaxLength::class);
    }
    foreach (FieldValues::of($value) as $delta => $item) {
      if (is_string($item) && mb_strlen($item, 'UTF-8') > $constraint->max) {
        $this->report($value, $delta, $constraint->message, ['@max' => $constraint->max], MeridianMaxLength::CODE);
      }
    }
  }

}
