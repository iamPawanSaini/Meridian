<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Validation;

use Drupal\Core\Field\FieldItemListInterface;

/**
 * Reads the main-property values of a field item list or of a plain value.
 *
 * The field constraints of this module accept a field item list (Drupal) or a
 * scalar or array (unit tests), so the same validator code runs in both.
 */
final class FieldValues {

  /**
   * Returns the non-empty values of a field, keyed by delta.
   *
   * @param mixed $value
   *   A field item list, an array of values or a scalar.
   *
   * @return array<int, mixed>
   *   The values keyed by delta. Empty items are left out.
   */
  public static function of(mixed $value): array {
    if ($value instanceof FieldItemListInterface) {
      $values = [];
      foreach ($value as $delta => $item) {
        $main = $item::mainPropertyName();
        $raw = $main === NULL ? NULL : $item->get($main)->getValue();
        if ($raw !== NULL && $raw !== '') {
          $values[(int) $delta] = $raw;
        }
      }
      return $values;
    }
    if (is_array($value)) {
      return array_values(array_filter($value, static fn ($v): bool => $v !== NULL && $v !== ''));
    }
    return ($value === NULL || $value === '') ? [] : [0 => $value];
  }

  /**
   * Whether violations must be reported per delta.
   */
  public static function isMultiple(mixed $value): bool {
    return $value instanceof FieldItemListInterface
      && $value->getFieldDefinition()->getFieldStorageDefinition()->getCardinality() !== 1;
  }

}
