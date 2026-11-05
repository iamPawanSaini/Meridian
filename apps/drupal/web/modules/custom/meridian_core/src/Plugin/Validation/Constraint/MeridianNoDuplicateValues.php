<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\Core\Validation\Attribute\Constraint;
use Symfony\Component\Validator\Constraint as SymfonyConstraint;

/**
 * No repeated values in a multi-value field.
 */
#[Constraint(
  id: 'MeridianNoDuplicateValues',
  label: new TranslatableMarkup('No repeated values in a multi-value field.', [], ['context' => 'Validation'])
)]
class MeridianNoDuplicateValues extends SymfonyConstraint {

  /**
   * The violation code.
   */
  public const CODE = 'meridian.duplicate_value';

  /**
   * The message.
   */
  public string $message = '@value is listed more than once.';

}
