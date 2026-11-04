<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\Core\Validation\Attribute\Constraint;
use Symfony\Component\Validator\Constraint as SymfonyConstraint;

/**
 * Value that cannot change after creation.
 */
#[Constraint(
  id: 'MeridianImmutable',
  label: new TranslatableMarkup('Value that cannot change after creation.', [], ['context' => 'Validation'])
)]
class MeridianImmutable extends SymfonyConstraint {

  /**
   * The violation code.
   */
  public const CODE = 'meridian.immutable';

  /**
   * The message.
   */
  public string $message = 'The @field cannot be changed after creation.';

}
