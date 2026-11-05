<?php

declare(strict_types=1);

namespace Drupal\Tests\meridian_core\Unit;

use Symfony\Component\Validator\Constraint;
use Symfony\Component\Validator\ConstraintValidator;
use Symfony\Component\Validator\Context\ExecutionContext;
use Symfony\Component\Validator\Validation;

/**
 * Runs a constraint validator on a plain value, without Drupal.
 */
trait ValidatorHarnessTrait {

  /**
   * Validates a value and returns the violation codes.
   *
   * @return string[]
   *   The codes, in the order reported.
   */
  protected function codes(ConstraintValidator $validator, mixed $value, Constraint $constraint): array {
    $translator = new IdentityTranslator();
    $context = new ExecutionContext(Validation::createValidator(), $value, $translator);
    $validator->initialize($context);
    $validator->validate($value, $constraint);
    $codes = [];
    foreach ($context->getViolations() as $violation) {
      $codes[] = (string) $violation->getCode();
    }
    return $codes;
  }

}
