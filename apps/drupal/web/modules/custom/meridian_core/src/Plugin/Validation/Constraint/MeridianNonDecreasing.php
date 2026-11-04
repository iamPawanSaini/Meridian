<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\Core\Validation\Attribute\Constraint;
use Symfony\Component\Validator\Constraint as SymfonyConstraint;

/**
 * Integer that never decreases.
 */
#[Constraint(
  id: 'MeridianNonDecreasing',
  label: new TranslatableMarkup('Integer that never decreases.', [], ['context' => 'Validation'])
)]
class MeridianNonDecreasing extends SymfonyConstraint {

  /**
   * The violation code.
   */
  public const CODE = 'meridian.non_decreasing';

  /**
   * The message.
   */
  public string $message = 'The value @value is lower than the stored value @stored.';

}
