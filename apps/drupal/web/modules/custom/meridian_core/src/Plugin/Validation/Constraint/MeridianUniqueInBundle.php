<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\Core\Validation\Attribute\Constraint;
use Symfony\Component\Validator\Constraint as SymfonyConstraint;

/**
 * Value unique within the content type.
 */
#[Constraint(
  id: 'MeridianUniqueInBundle',
  label: new TranslatableMarkup('Value unique within the content type.', [], ['context' => 'Validation'])
)]
class MeridianUniqueInBundle extends SymfonyConstraint {

  /**
   * The violation code.
   */
  public const CODE = 'meridian.unique_in_bundle';

  /**
   * The message.
   */
  public string $message = 'Another record of this content type already has this @field.';

}
