<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Schema;

use Drupal\Core\Database\Connection;

/**
 * The unique database key behind the external ID rule (KD-4).
 *
 * The key is on (bundle, field_external_id_value) of the dedicated field table
 * node__field_external_id, not on the revision table. It is the only rule that
 * also holds for a bare save() without validate(), and for two concurrent
 * creates of one Watchlist symbol (the external ID is wl-{symbol}).
 */
class ExternalIdIndex {

  /**
   * The dedicated field table of field_external_id.
   */
  public const TABLE = 'node__field_external_id';

  /**
   * The name of the unique key.
   */
  public const KEY = 'meridian_external_id_bundle';

  /**
   * The columns of the key, in order.
   */
  public const COLUMNS = ['bundle', 'field_external_id_value'];

  /**
   * Creates the service.
   */
  public function __construct(protected Connection $database) {
  }

  /**
   * Whether the field table exists.
   */
  public function tableExists(): bool {
    return $this->database->schema()->tableExists(self::TABLE);
  }

  /**
   * Whether the unique key exists.
   */
  public function exists(): bool {
    return $this->tableExists() && $this->database->schema()->indexExists(self::TABLE, self::KEY);
  }

  /**
   * Adds the unique key when the table exists and the key does not.
   *
   * @return bool
   *   TRUE when the key exists after the call.
   */
  public function ensure(): bool {
    if (!$this->tableExists()) {
      return FALSE;
    }
    if (!$this->exists()) {
      $this->database->schema()->addUniqueKey(self::TABLE, self::KEY, self::COLUMNS);
    }
    return $this->exists();
  }

  /**
   * Drops the unique key when it exists.
   */
  public function drop(): void {
    if ($this->exists()) {
      $this->database->schema()->dropUniqueKey(self::TABLE, self::KEY);
    }
  }

}
