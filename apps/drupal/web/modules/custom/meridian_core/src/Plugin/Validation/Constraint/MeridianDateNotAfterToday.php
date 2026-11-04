<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\Core\Validation\Attribute\Constraint;
use Symfony\Component\Validator\Constraint as SymfonyConstraint;

/**
 * Date not after today in India Standard Time.
 */
#[Constraint(
  id: 'MeridianDateNotAfterToday',
  label: new TranslatableMarkup('Date not after today in India Standard Time.', [], ['context' => 'Validation'])
)]
class MeridianDateNotAfterToday extends SymfonyConstraint {

  /**
   * The violation code.
   */
  public const CODE = 'meridian.date_in_future';

  /**
   * The message.
   */
  public string $message = 'The date @value is after today (Asia/Kolkata).';

}
