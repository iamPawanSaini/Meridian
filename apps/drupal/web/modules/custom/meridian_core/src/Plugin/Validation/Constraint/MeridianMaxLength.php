<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\Core\Validation\Attribute\Constraint;
use Symfony\Component\Validator\Attribute\HasNamedArguments;
use Symfony\Component\Validator\Constraint as SymfonyConstraint;

/**
 * Text no longer than a number of characters.
 */
#[Constraint(
  id: 'MeridianMaxLength',
  label: new TranslatableMarkup('Text no longer than a number of characters.', [], ['context' => 'Validation'])
)]
class MeridianMaxLength extends SymfonyConstraint {

  /**
   * The violation code.
   */
  public const CODE = 'meridian.max_length';

  /**
   * Creates the constraint.
   *
   * @param int $max
   *   The maximum number of characters.
   * @param string $message
   *   The message.
   * @param string[]|null $groups
   *   Validation groups.
   * @param mixed $payload
   *   Payload.
   */
  #[HasNamedArguments]
  public function __construct(
    public int $max = 0,
    public string $message = 'The text is longer than @max characters.',
    ?array $groups = NULL,
    mixed $payload = NULL,
  ) {
    parent::__construct(NULL, $groups, $payload);
  }

}
