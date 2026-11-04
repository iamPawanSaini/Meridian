<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\Core\Validation\Attribute\Constraint;
use Symfony\Component\Validator\Constraint as SymfonyConstraint;

/**
 * Cross-field rules of the position content type.
 *
 * The violation codes are meridian.position.* and are set by the validator.
 */
#[Constraint(
  id: 'MeridianPositionRules',
  label: new TranslatableMarkup('Meridian Position rules', [], ['context' => 'Validation'])
)]
class MeridianPositionRules extends SymfonyConstraint {

}
