<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\Core\Validation\Attribute\Constraint;
use Symfony\Component\Validator\Attribute\HasNamedArguments;
use Symfony\Component\Validator\Constraint as SymfonyConstraint;

/**
 * Value matches a regular expression.
 */
#[Constraint(
  id: 'MeridianPattern',
  label: new TranslatableMarkup('Value matches a regular expression.', [], ['context' => 'Validation'])
)]
class MeridianPattern extends SymfonyConstraint {

  /**
   * The violation code.
   */
  public const CODE = 'meridian.pattern';

  /**
   * Creates the constraint.
   *
   * @param string $pattern
   *   A pattern constant of Drupal\meridian_core\Validation\Patterns.
   * @param string $message
   *   The message.
   * @param string[]|null $groups
   *   Validation groups.
   * @param mixed $payload
   *   Payload.
   */
  #[HasNamedArguments]
  public function __construct(
    public string $pattern = '',
    public string $message = 'The value does not match the required format.',
    ?array $groups = NULL,
    mixed $payload = NULL,
  ) {
    parent::__construct(NULL, $groups, $payload);
  }

}
