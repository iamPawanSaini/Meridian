<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\Core\Validation\Attribute\Constraint;
use Symfony\Component\Validator\Constraint as SymfonyConstraint;

/**
 * Value allowed for this bundle only.
 */
#[Constraint(
  id: 'MeridianBundleAllowedValues',
  label: new TranslatableMarkup('Value allowed for this bundle only.', [], ['context' => 'Validation'])
)]
class MeridianBundleAllowedValues extends SymfonyConstraint {

  /**
   * The violation code.
   */
  public const CODE = 'meridian.bundle_allowed_values';

  /**
   * The message.
   */
  public string $message = '@value is not allowed for this content type.';

}
