<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\Core\Validation\Attribute\Constraint;
use Symfony\Component\Validator\Attribute\HasNamedArguments;
use Symfony\Component\Validator\Constraint as SymfonyConstraint;

/**
 * Decimal fits the field precision and scale.
 */
#[Constraint(
  id: 'MeridianDecimalScale',
  label: new TranslatableMarkup('Decimal fits the field precision and scale.', [], ['context' => 'Validation'])
)]
class MeridianDecimalScale extends SymfonyConstraint {

  /**
   * The code for too many fractional digits.
   */
  public const CODE_SCALE = 'meridian.decimal_scale';

  /**
   * The code for too many integer digits.
   */
  public const CODE_PRECISION = 'meridian.decimal_precision';

  /**
   * Creates the constraint.
   *
   * @param int $precision
   *   The total number of digits of the field.
   * @param int $scale
   *   The number of fractional digits of the field.
   * @param bool $integerDigits
   *   Whether to check the integer digits. Fields with a Range maximum leave
   *   this off, so one bad value gives one violation.
   * @param string[]|null $groups
   *   Validation groups.
   * @param mixed $payload
   *   Payload.
   */
  #[HasNamedArguments]
  public function __construct(
    public int $precision = 0,
    public int $scale = 0,
    public bool $integerDigits = TRUE,
    ?array $groups = NULL,
    mixed $payload = NULL,
  ) {
    parent::__construct(NULL, $groups, $payload);
  }

}
