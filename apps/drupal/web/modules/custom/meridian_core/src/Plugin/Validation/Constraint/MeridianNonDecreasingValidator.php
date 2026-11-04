<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\DependencyInjection\ContainerInjectionInterface;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\Core\Entity\FieldableEntityInterface;
use Drupal\Core\Field\FieldItemListInterface;
use Drupal\meridian_core\Validation\FieldValidatorBase;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\Validator\Constraint;
use Symfony\Component\Validator\Exception\UnexpectedTypeException;

/**
 * Validates MeridianNonDecreasing (D3: source_version never decreases).
 *
 * Compares with the stored entity (loadUnchanged).
 */
final class MeridianNonDecreasingValidator extends FieldValidatorBase implements ContainerInjectionInterface {

  /**
   * Creates the validator.
   */
  public function __construct(protected EntityTypeManagerInterface $entityTypeManager) {
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container): static {
    return new static($container->get('entity_type.manager'));
  }

  /**
   * {@inheritdoc}
   */
  public function validate(mixed $value, Constraint $constraint): void {
    if (!$constraint instanceof MeridianNonDecreasing) {
      throw new UnexpectedTypeException($constraint, MeridianNonDecreasing::class);
    }
    if (!$value instanceof FieldItemListInterface) {
      return;
    }
    $entity = $value->getEntity();
    $new = $value->value;
    if ($entity->isNew() || !is_numeric($new)) {
      return;
    }
    $stored = $this->entityTypeManager->getStorage($entity->getEntityTypeId())->loadUnchanged($entity->id());
    $old = $stored instanceof FieldableEntityInterface ? $stored->get($value->getName())->value : NULL;
    if (is_numeric($old) && (int) $new < (int) $old) {
      $this->reportField($constraint->message, ['@value' => (int) $new, '@stored' => (int) $old], MeridianNonDecreasing::CODE);
    }
  }

}
