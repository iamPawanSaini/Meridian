<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Validation;

use Symfony\Component\Validator\ConstraintValidator;

/**
 * Base of the Meridian field constraint validators.
 *
 * Violations are reported at the field path. For a multi-value field a
 * violation about one value is reported at that delta.
 */
abstract class FieldValidatorBase extends ConstraintValidator {

  /**
   * Adds a violation for one value.
   *
   * @param mixed $field
   *   The validated value (field item list, or a plain value in unit tests).
   * @param int $delta
   *   The delta of the offending value.
   * @param string $message
   *   The message, with placeholders.
   * @param array<string, mixed> $params
   *   The placeholder values.
   * @param string $code
   *   The stable violation code (meridian.*).
   */
  protected function report(mixed $field, int $delta, string $message, array $params, string $code): void {
    $builder = $this->context->buildViolation($message, $params)->setCode($code);
    if (FieldValues::isMultiple($field)) {
      $builder->atPath((string) $delta);
    }
    $builder->addViolation();
  }

  /**
   * Adds a violation for the whole field.
   *
   * @param string $message
   *   The message, with placeholders.
   * @param array<string, mixed> $params
   *   The placeholder values.
   * @param string $code
   *   The stable violation code (meridian.*).
   */
  protected function reportField(string $message, array $params, string $code): void {
    $this->context->buildViolation($message, $params)->setCode($code)->addViolation();
  }

}
