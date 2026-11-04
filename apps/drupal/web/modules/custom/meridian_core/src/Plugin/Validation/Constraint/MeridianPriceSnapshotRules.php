<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\Core\Validation\Attribute\Constraint;
use Symfony\Component\Validator\Constraint as SymfonyConstraint;

/**
 * Cross-field rules of the price_snapshot content type.
 *
 * The violation codes are meridian.price_snapshot.*, set by the validator.
 */
#[Constraint(
  id: 'MeridianPriceSnapshotRules',
  label: new TranslatableMarkup('Meridian PriceSnapshot rules', [], ['context' => 'Validation'])
)]
class MeridianPriceSnapshotRules extends SymfonyConstraint {

}
