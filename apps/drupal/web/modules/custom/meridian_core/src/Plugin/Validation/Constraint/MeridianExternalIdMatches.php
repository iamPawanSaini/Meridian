<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\Core\Validation\Attribute\Constraint;
use Symfony\Component\Validator\Constraint as SymfonyConstraint;

/**
 * External ID equals the key built from the own fields of the record.
 */
#[Constraint(
  id: 'MeridianExternalIdMatches',
  label: new TranslatableMarkup('External ID equals the key built from the own fields of the record.', [], ['context' => 'Validation'])
)]
class MeridianExternalIdMatches extends SymfonyConstraint {

  /**
   * The violation code.
   */
  public const CODE = 'meridian.external_id_mismatch';

  /**
   * The message.
   */
  public string $message = 'The external ID must be @expected.';

}
