<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\meridian_core\Validation\FieldValidatorBase;
use Drupal\meridian_core\Validation\FieldValues;
use Symfony\Component\Validator\Constraint;
use Symfony\Component\Validator\Exception\UnexpectedTypeException;

/**
 * Validates MeridianJsonDocument.
 *
 * The size is the UTF-8 byte length of the stored string. An empty value is
 * left to the required rule.
 */
class MeridianJsonDocumentValidator extends FieldValidatorBase {

  /**
   * {@inheritdoc}
   */
  public function validate(mixed $value, Constraint $constraint): void {
    if (!$constraint instanceof MeridianJsonDocument) {
      throw new UnexpectedTypeException($constraint, MeridianJsonDocument::class);
    }
    foreach (FieldValues::of($value) as $delta => $item) {
      if (!is_string($item)) {
        $this->report($value, $delta, 'The value is not valid JSON.', [], MeridianJsonDocument::CODE_INVALID);
        continue;
      }
      try {
        $decoded = json_decode($item, FALSE, 512, JSON_THROW_ON_ERROR);
      }
      catch (\JsonException) {
        $this->report($value, $delta, 'The value is not valid JSON.', [], MeridianJsonDocument::CODE_INVALID);
        continue;
      }
      if ($constraint->objectOnly && !$decoded instanceof \stdClass) {
        $this->report($value, $delta, 'The JSON value must be an object.', [], MeridianJsonDocument::CODE_NOT_OBJECT);
        continue;
      }
      if (strlen($item) > $constraint->maxBytes) {
        $this->report($value, $delta, 'The JSON document is larger than @max bytes.', ['@max' => $constraint->maxBytes], MeridianJsonDocument::CODE_TOO_LARGE);
      }
    }
  }

}
