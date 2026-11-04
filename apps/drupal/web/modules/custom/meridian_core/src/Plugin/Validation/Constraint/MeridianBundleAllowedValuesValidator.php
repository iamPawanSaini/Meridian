<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\Field\FieldItemListInterface;
use Drupal\field\FieldConfigInterface;
use Drupal\meridian_core\Validation\FieldValidatorBase;
use Drupal\meridian_core\Validation\FieldValues;
use Symfony\Component\Validator\Constraint;
use Symfony\Component\Validator\Exception\UnexpectedTypeException;

/**
 * Validates MeridianBundleAllowedValues (DN-3).
 *
 * The allowed values of the bundle are the third-party setting
 * meridian_core.allowed_values of the field instance. A value that is outside
 * the storage list is left to the core allowed-values rule, so one bad value
 * gives one violation.
 */
class MeridianBundleAllowedValuesValidator extends FieldValidatorBase {

  /**
   * {@inheritdoc}
   */
  public function validate(mixed $value, Constraint $constraint): void {
    if (!$constraint instanceof MeridianBundleAllowedValues) {
      throw new UnexpectedTypeException($constraint, MeridianBundleAllowedValues::class);
    }
    if (!$value instanceof FieldItemListInterface) {
      return;
    }
    $definition = $value->getFieldDefinition();
    if (!$definition instanceof FieldConfigInterface) {
      return;
    }
    $allowed = $definition->getThirdPartySetting('meridian_core', 'allowed_values');
    if (!is_array($allowed)) {
      return;
    }
    $storage_values = array_map('strval', array_keys($definition->getFieldStorageDefinition()->getSetting('allowed_values') ?? []));
    foreach (FieldValues::of($value) as $delta => $item) {
      $item = (string) $item;
      if (in_array($item, $storage_values, TRUE) && !in_array($item, array_map('strval', $allowed), TRUE)) {
        $this->report($value, $delta, $constraint->message, ['@value' => $item], MeridianBundleAllowedValues::CODE);
      }
    }
  }

}
