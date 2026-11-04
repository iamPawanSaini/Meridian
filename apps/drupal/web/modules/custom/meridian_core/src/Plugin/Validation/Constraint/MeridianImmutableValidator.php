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
 * Validates MeridianImmutable (D1, DN-8).
 *
 * Compares with the stored entity (loadUnchanged), so a stale in-memory copy
 * cannot bypass the rule. A new entity has nothing to compare with.
 */
final class MeridianImmutableValidator extends FieldValidatorBase implements ContainerInjectionInterface {

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
    if (!$constraint instanceof MeridianImmutable) {
      throw new UnexpectedTypeException($constraint, MeridianImmutable::class);
    }
    if (!$value instanceof FieldItemListInterface) {
      return;
    }
    $entity = $value->getEntity();
    $after = $value->value;
    // An empty value is reported by the required rule, not by this one.
    if ($entity->isNew() || $after === NULL || $after === '') {
      return;
    }
    $stored = $this->entityTypeManager->getStorage($entity->getEntityTypeId())->loadUnchanged($entity->id());
    if (!$stored instanceof FieldableEntityInterface) {
      return;
    }
    $field = $value->getName();
    $before = $stored->get($field)->value;
    if ($before !== NULL && $before !== '' && (string) $before !== (string) $after) {
      $this->reportField($constraint->message, ['@field' => $field], MeridianImmutable::CODE);
    }
  }

}
