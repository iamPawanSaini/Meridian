<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\DependencyInjection\ContainerInjectionInterface;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\Core\Entity\FieldableEntityInterface;
use Drupal\Core\Field\FieldItemListInterface;
use Drupal\meridian_core\Validation\FieldValidatorBase;
use Drupal\meridian_core\Validation\FieldValues;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\Validator\Constraint;
use Symfony\Component\Validator\Exception\UnexpectedTypeException;

/**
 * Validates MeridianUniqueInBundle (KD-4).
 *
 * Core UniqueField checks the whole entity type, and the field storage is
 * shared by the bundles. This check adds the bundle condition, ignores access,
 * excludes the entity itself and compares exactly: the query finds candidates
 * and a case-sensitive string comparison confirms them, so the case of letters
 * and the characters % and _ never match by accident.
 */
final class MeridianUniqueInBundleValidator extends FieldValidatorBase implements ContainerInjectionInterface {

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
    if (!$constraint instanceof MeridianUniqueInBundle) {
      throw new UnexpectedTypeException($constraint, MeridianUniqueInBundle::class);
    }
    if (!$value instanceof FieldItemListInterface) {
      return;
    }
    $entity = $value->getEntity();
    $field = $value->getName();
    // A Watchlist Item external ID is wl-{symbol}, so a duplicate symbol is
    // also a duplicate ID. The symbol is reported once, at field_symbol.
    if ($entity->bundle() === 'watchlist_item' && $field === 'field_external_id'
      && $this->isDuplicate($entity, 'field_symbol')) {
      return;
    }
    foreach (FieldValues::of($value) as $delta => $item) {
      if ($this->isDuplicate($entity, $field, $item)) {
        $this->report($value, $delta, $constraint->message, ['@field' => $field], MeridianUniqueInBundle::CODE);
      }
    }
  }

  /**
   * Whether another entity of the bundle holds the same value (exact).
   *
   * @param \Drupal\Core\Entity\FieldableEntityInterface $entity
   *   The entity being validated.
   * @param string $field
   *   The field machine name.
   * @param mixed $item
   *   The value to look for. NULL means the current value of the field.
   */
  protected function isDuplicate(FieldableEntityInterface $entity, string $field, mixed $item = NULL): bool {
    $item ??= $entity->get($field)->value;
    if (!is_string($item)) {
      return FALSE;
    }
    $storage = $this->entityTypeManager->getStorage($entity->getEntityTypeId());
    $query = $storage->getQuery()
      ->accessCheck(FALSE)
      ->condition($entity->getEntityType()->getKey('bundle'), $entity->bundle())
      ->condition($field . '.value', $item);
    if (!$entity->isNew()) {
      $query->condition($entity->getEntityType()->getKey('id'), $entity->id(), '<>');
    }
    foreach ($storage->loadMultiple($query->execute()) as $other) {
      if ($other instanceof FieldableEntityInterface && $other->get($field)->value === $item) {
        return TRUE;
      }
    }
    return FALSE;
  }

}
