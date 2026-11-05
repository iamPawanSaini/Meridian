<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\Core\Validation\Attribute\Constraint;
use Symfony\Component\Validator\Attribute\HasNamedArguments;
use Symfony\Component\Validator\Constraint as SymfonyConstraint;

/**
 * Valid JSON document of limited size.
 */
#[Constraint(
  id: 'MeridianJsonDocument',
  label: new TranslatableMarkup('Valid JSON document of limited size.', [], ['context' => 'Validation'])
)]
class MeridianJsonDocument extends SymfonyConstraint {

  /**
   * The code for text that is not valid JSON.
   */
  public const CODE_INVALID = 'meridian.json_invalid';

  /**
   * The code for JSON that is not an object.
   */
  public const CODE_NOT_OBJECT = 'meridian.json_not_object';

  /**
   * The code for a document over the byte limit.
   */
  public const CODE_TOO_LARGE = 'meridian.json_too_large';

  /**
   * Creates the constraint.
   *
   * @param bool $objectOnly
   *   Whether the document must be a JSON object.
   * @param int $maxBytes
   *   The maximum size in UTF-8 bytes.
   * @param string[]|null $groups
   *   Validation groups.
   * @param mixed $payload
   *   Payload.
   */
  #[HasNamedArguments]
  public function __construct(
    public bool $objectOnly = TRUE,
    public int $maxBytes = 65536,
    ?array $groups = NULL,
    mixed $payload = NULL,
  ) {
    parent::__construct(NULL, $groups, $payload);
  }

}
