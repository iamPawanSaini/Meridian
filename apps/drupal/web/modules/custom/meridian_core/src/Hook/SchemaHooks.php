<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Hook;

use Drupal\Core\Hook\Attribute\Hook;
use Drupal\field\FieldStorageConfigInterface;
use Drupal\meridian_core\Schema\ExternalIdIndex;

/**
 * Adds the unique external ID key when the field storage is saved (KD-4).
 */
class SchemaHooks {

  /**
   * Creates the hooks.
   */
  public function __construct(protected ExternalIdIndex $index) {
  }

  /**
   * Implements hook_field_storage_config_insert().
   */
  #[Hook('field_storage_config_insert')]
  public function fieldStorageInsert(FieldStorageConfigInterface $storage): void {
    $this->ensureKey($storage);
  }

  /**
   * Implements hook_field_storage_config_update().
   *
   * Core drops and recreates the dedicated tables of a field storage without
   * data when the storage is updated, which removes the key. The key is added
   * again here.
   */
  #[Hook('field_storage_config_update')]
  public function fieldStorageUpdate(FieldStorageConfigInterface $storage): void {
    $this->ensureKey($storage);
  }

  /**
   * Adds the key when the storage is the node external ID.
   */
  protected function ensureKey(FieldStorageConfigInterface $storage): void {
    if ($storage->getTargetEntityTypeId() === 'node' && $storage->getName() === 'field_external_id') {
      $this->index->ensure();
    }
  }

}
