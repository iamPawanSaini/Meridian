<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\Core\Validation\Attribute\Constraint;
use Symfony\Component\Validator\Constraint as SymfonyConstraint;

/**
 * Cross-field rules of the daily_run content type.
 *
 * The violation codes are meridian.daily_run.* and are set by the validator.
 */
#[Constraint(
  id: 'MeridianDailyRunRules',
  label: new TranslatableMarkup('Meridian DailyRun rules', [], ['context' => 'Validation'])
)]
class MeridianDailyRunRules extends SymfonyConstraint {

}
