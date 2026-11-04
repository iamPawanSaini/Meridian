<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\Field\FieldItemListInterface;
use Drupal\meridian_core\Validation\FieldValidatorBase;
use Drupal\meridian_core\Validation\FieldValues;
use Drupal\meridian_core\Validation\Patterns;
use Symfony\Component\Validator\Constraint;
use Symfony\Component\Validator\Exception\UnexpectedTypeException;

/**
 * Validates MeridianPattern.
 *
 * A value longer than the max_length of the field is left to the core Length
 * rule.
 */
class MeridianPatternValidator extends FieldValidatorBase {

  /**
   * {@inheritdoc}
   */
  public function validate(mixed $value, Constraint $constraint): void {
    if (!$constraint instanceof MeridianPattern) {
      throw new UnexpectedTypeException($constraint, MeridianPattern::class);
    }
    $max_length = $value instanceof FieldItemListInterface
      ? $value->getFieldDefinition()->getFieldStorageDefinition()->getSetting('max_length')
      : NULL;
    foreach (FieldValues::of($value) as $delta => $item) {
      // A value longer than the column is reported by the max_length rule, so
      // one defect gives one violation.
      if (is_int($max_length) && is_string($item) && mb_strlen($item) > $max_length) {
        continue;
      }
      if (!Patterns::matches($constraint->pattern, $item)) {
        $this->report($value, $delta, $constraint->message, [], MeridianPattern::CODE);
      }
    }
  }

}
