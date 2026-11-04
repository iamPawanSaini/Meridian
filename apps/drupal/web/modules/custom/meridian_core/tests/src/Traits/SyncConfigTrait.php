<?php

declare(strict_types=1);

namespace Drupal\Tests\meridian_core\Traits;

use Drupal\Core\Config\FileStorage;
use Drupal\Core\Config\Entity\ConfigEntityStorageInterface;

/**
 * Creates the shipped content model in a Kernel test from config/sync (KD-1).
 *
 * The tests therefore run against the YAML the site installs, not a copy.
 * The directory can be replaced for mutation checks by a protected property
 * ($syncConfigDirectory) or by the environment variable MERIDIAN_SYNC_DIR.
 */
trait SyncConfigTrait {

  /**
   * Overrides the config directory. NULL means apps/drupal/config/sync.
   */
  protected ?string $syncConfigDirectory = NULL;

  /**
   * The config entity types of the content model, in dependency order.
   */
  protected const SYNC_PREFIXES = [
    'node.type.',
    'field.storage.node.',
    'field.field.node.',
    'user.role.',
  ];

  /**
   * Returns the directory with the exported config.
   */
  protected function syncDirectory(): string {
    $override = $this->syncConfigDirectory ?? (getenv('MERIDIAN_SYNC_DIR') ?: NULL);
    if ($override !== NULL) {
      return $override;
    }
    return dirname(__DIR__, 7) . '/config/sync';
  }

  /**
   * Creates the content model and the roles from the sync directory.
   *
   * @param string[]|null $prefixes
   *   The config name prefixes to create. NULL means all of SYNC_PREFIXES.
   */
  protected function installSyncedConfig(?array $prefixes = NULL): void {
    $source = new FileStorage($this->syncDirectory());
    $manager = $this->container->get('config.manager');
    foreach ($prefixes ?? self::SYNC_PREFIXES as $prefix) {
      foreach ($source->listAll($prefix) as $name) {
        $type = $manager->getEntityTypeIdByName($name);
        $storage = $this->container->get('entity_type.manager')->getStorage($type);
        assert($storage instanceof ConfigEntityStorageInterface);
        $entity = $storage->createFromStorageRecord($source->read($name));
        $entity->save();
      }
    }
  }

}
