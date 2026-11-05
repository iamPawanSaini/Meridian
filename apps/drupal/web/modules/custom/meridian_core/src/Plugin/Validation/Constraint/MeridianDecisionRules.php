<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\Core\Validation\Attribute\Constraint;
use Symfony\Component\Validator\Constraint as SymfonyConstraint;

/**
 * Cross-field rules of the decision content type.
 *
 * The violation codes are meridian.decision.* and are set by the validator.
 */
#[Constraint(
  id: 'MeridianDecisionRules',
  label: new TranslatableMarkup('Meridian Decision rules', [], ['context' => 'Validation'])
)]
class MeridianDecisionRules extends SymfonyConstraint {

}
