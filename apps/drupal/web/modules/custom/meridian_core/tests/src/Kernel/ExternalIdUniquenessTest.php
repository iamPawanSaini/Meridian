<?php

declare(strict_types=1);

// phpcs:disable Drupal.Arrays.Array.LongLineDeclaration -- T09: one test case per line

namespace Drupal\Tests\meridian_core\Kernel;

use Drupal\Core\Database\Database;
use Drupal\Core\Entity\EntityStorageException;
use Drupal\field\Entity\FieldStorageConfig;
use Drupal\meridian_core\Schema\ExternalIdIndex;
use Drupal\node\Entity\Node;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\RunTestsInSeparateProcesses;

/**
 * Unique external ID per bundle, at entity level and in the database.
 *
 * Covers TC-T09-31 to TC-T09-36. The database key is the first choice of
 * KD-4 (no fallback was needed, see the README of meridian_core).
 */
#[Group('meridian_core')]
#[RunTestsInSeparateProcesses]
class ExternalIdUniquenessTest extends MeridianKernelTestBase {

  /**
   * The index service.
   */
  protected function index(): ExternalIdIndex {
    return $this->container->get('meridian_core.external_id_index');
  }

  /**
   * Counts the nodes of a bundle.
   */
  protected function countNodes(string $bundle): int {
    return (int) $this->container->get('entity_type.manager')->getStorage('node')
      ->getQuery()->accessCheck(FALSE)->condition('type', $bundle)->count()->execute();
  }

  /**
   * A second record with the same external ID is rejected on each bundle.
   */
  public function testDuplicateIsRejectedByValidate(): void {
    $duplicate = ['field_external_id', 'meridian.unique_in_bundle'];
    foreach (['daily_run', 'decision', 'position', 'price_snapshot', 'watchlist_item'] as $bundle) {
      $first = $this->record($bundle);
      $this->assertValid($first, "$bundle: first record");
      $first->save();
      $expected = $bundle === 'watchlist_item' ? [$duplicate, ['field_symbol', 'meridian.unique_in_bundle']] : [$duplicate];
      $this->assertViolations($this->record($bundle), $expected, "$bundle: second record with the same id");
      $loaded = Node::load($first->id());
      $loaded->set('title', 'Updated');
      $loaded->setNewRevision(TRUE);
      $this->assertValid($loaded, "$bundle: update of the same node (own id excluded)");
    }
  }

  /**
   * An unpublished record still counts.
   */
  public function testUnpublishedDuplicateCounts(): void {
    $first = $this->record('price_snapshot');
    $first->setUnpublished();
    $first->save();
    $this->assertRejected($this->record('price_snapshot'), 'field_external_id', 'meridian.unique_in_bundle', 'unpublished duplicate');
  }

  /**
   * The comparison is exact: no wildcards, no letter case (TC-T09-32).
   */
  public function testComparisonIsExact(): void {
    // Bare saves: these values are not valid external IDs and are set only to
    // test the uniqueness rule alone.
    foreach (['wl-A_B', 'wl-abc', 'wl-A%'] as $stored) {
      $node = Node::create(['type' => 'watchlist_item', 'title' => $stored, 'field_external_id' => $stored, 'field_symbol' => 'S' . crc32($stored)]);
      $node->save();
    }
    $unique = static function (string $id): array {
      $probe = Node::create(['type' => 'watchlist_item', 'title' => 'probe', 'field_external_id' => $id]);
      $codes = [];
      foreach ($probe->get('field_external_id')->validate() as $violation) {
        $codes[] = $violation->getCode();
      }
      return array_values(array_intersect($codes, ['meridian.unique_in_bundle']));
    };
    $this->assertSame([], $unique('wl-AXB'), '_ is not a wildcard');
    $this->assertSame([], $unique('wl-ABC'), 'letter case differs');
    $this->assertSame([], $unique('wl-AB'), '% is not a wildcard');
    $this->assertSame(['meridian.unique_in_bundle'], $unique('wl-A_B'), 'the exact value is a duplicate');
    $this->assertSame(['meridian.unique_in_bundle'], $unique('wl-abc'), 'the exact lowercase value is a duplicate');
  }

  /**
   * Different bundles may hold the same string (the key has the bundle).
   */
  public function testSameValueInAnotherBundleIsAllowed(): void {
    $decision = Node::create(['type' => 'decision', 'title' => 'a', 'field_external_id' => 'shared-id']);
    $decision->save();
    $price = Node::create(['type' => 'price_snapshot', 'title' => 'b', 'field_external_id' => 'shared-id']);
    $price->save();
    $this->assertNotEmpty($price->id());
    foreach ([$decision, $price] as $node) {
      $codes = [];
      foreach ($node->get('field_external_id')->validate() as $violation) {
        $codes[] = $violation->getCode();
      }
      $this->assertNotContains('meridian.unique_in_bundle', $codes, $node->bundle());
    }
  }

  /**
   * A bare save of a duplicate throws and leaves nothing behind (TC-T09-34).
   */
  public function testDatabaseKeyRejectsDuplicateSave(): void {
    $this->assertTrue($this->index()->exists(), 'the key exists after the config install');
    $connection = Database::getConnection();
    $keys = $connection->query("SHOW INDEX FROM {node__field_external_id} WHERE Key_name = 'meridian_external_id_bundle'")->fetchAll();
    usort($keys, static fn ($a, $b) => (int) $a->Seq_in_index <=> (int) $b->Seq_in_index);
    $this->assertSame(['bundle', 'field_external_id_value'], array_map(static fn ($row) => $row->Column_name, $keys));
    $this->assertSame(['0', '0'], array_map(static fn ($row) => (string) $row->Non_unique, $keys), 'the key is unique');
    $revision_keys = $connection->query("SHOW INDEX FROM {node_revision__field_external_id} WHERE Key_name = 'meridian_external_id_bundle'")->fetchAll();
    $this->assertSame([], $revision_keys, 'no key on the revision table');

    $this->record('decision')->save();
    $before = [$this->countNodes('decision'), (int) $connection->query('SELECT COUNT(*) FROM {node_field_data}')->fetchField(), (int) $connection->query('SELECT COUNT(*) FROM {node__field_external_id}')->fetchField()];
    try {
      $this->record('decision')->save();
      $this->fail('A duplicate external ID must not be saved.');
    }
    catch (EntityStorageException) {
      // Expected: the whole save is rolled back.
    }
    $after = [$this->countNodes('decision'), (int) $connection->query('SELECT COUNT(*) FROM {node_field_data}')->fetchField(), (int) $connection->query('SELECT COUNT(*) FROM {node__field_external_id}')->fetchField()];
    $this->assertSame($before, $after, 'no node row, field row or revision row is left');
    $this->assertSame((int) $connection->query('SELECT COUNT(*) FROM {node_field_data}')->fetchField(), (int) $connection->query('SELECT COUNT(*) FROM {node}')->fetchField());
  }

  /**
   * Two creates of one Watchlist symbol that both validate (TC-T09-35).
   */
  public function testConcurrentWatchlistCreatesAreStoppedByTheKey(): void {
    $first = $this->record('watchlist_item');
    $second = $this->record('watchlist_item');
    $this->assertValid($first, 'first validates');
    $this->assertValid($second, 'second validates too: the check-then-act race');
    $first->save();
    try {
      $second->save();
      $this->fail('The second save must fail.');
    }
    catch (EntityStorageException) {
      // Expected.
    }
    $this->assertSame(1, $this->countNodes('watchlist_item'));
  }

  /**
   * The key exists after each install path and is removed on uninstall.
   */
  public function testKeyLifecycle(): void {
    $index = $this->index();
    $this->assertTrue($index->exists(), 'field-storage path: created with the field storage');

    // Module install with the table already present.
    $index->drop();
    $this->assertFalse($index->exists());
    $this->container->get('module_handler')->loadInclude('meridian_core', 'install');
    meridian_core_install();
    $this->assertTrue($index->exists(), 'install path with an existing table');

    // A cache rebuild and a field storage update keep the key.
    drupal_flush_all_caches();
    $this->assertTrue($this->index()->exists(), 'after a cache rebuild');
    FieldStorageConfig::loadByName('node', 'field_external_id')->save();
    $this->assertTrue($this->index()->exists(), 'after a field storage update');
    $this->assertTrue($this->index()->ensure(), 'ensure() is idempotent');

    meridian_core_uninstall();
    $this->assertFalse($this->index()->exists(), 'removed on uninstall');
    $this->assertTrue($this->index()->tableExists());
    $this->index()->drop();
  }

}
