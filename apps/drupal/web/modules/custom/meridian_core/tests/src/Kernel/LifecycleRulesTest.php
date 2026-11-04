<?php

declare(strict_types=1);

// phpcs:disable Drupal.Arrays.Array.LongLineDeclaration -- T09: one test case per line

namespace Drupal\Tests\meridian_core\Kernel;

use Drupal\node\Entity\Node;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\RunTestsInSeparateProcesses;

/**
 * Immutable external IDs and non-decreasing source versions (TC-T09-26, 27).
 */
#[Group('meridian_core')]
#[RunTestsInSeparateProcesses]
class LifecycleRulesTest extends MeridianKernelTestBase {

  /**
   * Changed external IDs per bundle: a new ID for the same fields.
   */
  protected const NEW_IDS = [
    'daily_run' => 'run-2026-11-04',
    'decision' => 'dec-2026-11-04-RELIANCE-long',
    'position' => 'pos-RELIANCE-long-2026-11-04',
    'price_snapshot' => 'px-2026-11-04-RELIANCE',
    'watchlist_item' => 'wl-TCS',
  ];

  /**
   * The natural-key fields and a new value for each, per bundle (DN-5).
   */
  protected const NATURAL_KEYS = [
    'daily_run' => ['field_trade_date' => '2026-11-02'],
    'decision' => ['field_trade_date' => '2026-11-02', 'field_symbol' => 'TCS', 'field_mode' => 'short'],
    'position' => ['field_symbol' => 'TCS', 'field_mode' => 'short', 'field_entry_date' => '2026-11-04'],
    'price_snapshot' => ['field_trade_date' => '2026-11-02', 'field_symbol' => 'TCS'],
  ];

  /**
   * A changed external ID is rejected on every bundle.
   */
  public function testExternalIdIsImmutable(): void {
    foreach (self::NEW_IDS as $bundle => $new_id) {
      $record = $this->savedBaseline($bundle);
      $loaded = Node::load($record->id());
      $this->assertValid($loaded, "$bundle: unchanged record");
      $loaded->set('title', 'Changed title');
      $this->assertValid($loaded, "$bundle: title change");
      $loaded->set('field_external_id', $new_id);
      $this->assertRejected($loaded, 'field_external_id', 'meridian.immutable', "$bundle: external_id changed");
    }
    // Changing the fields too is still one violation.
    $record = $this->record('daily_run', ['field_external_id' => 'run-2026-10-01', 'field_trade_date' => '2026-10-01']);
    $record->save();
    $loaded = Node::load($record->id());
    $loaded->set('field_external_id', 'run-2026-10-02');
    $loaded->set('field_trade_date', '2026-10-02');
    $this->assertRejected($loaded, 'field_external_id', 'meridian.immutable', 'id and date changed together');
  }

  /**
   * A changed natural-key field is an external ID mismatch (DN-5).
   */
  public function testNaturalKeyChangeIsMismatch(): void {
    foreach (self::NATURAL_KEYS as $bundle => $changes) {
      $record = $this->savedBaseline($bundle);
      foreach ($changes as $field => $value) {
        $loaded = Node::load($record->id());
        $loaded->set($field, $value);
        if ($bundle === 'position' && $field === 'field_mode') {
          $loaded->set('field_time_stop_date', '2026-11-10');
        }
        $expected = [['field_external_id', 'meridian.external_id_mismatch']];
        if ($bundle === 'position' && $field === 'field_symbol') {
          $expected[] = ['field_decision', 'meridian.position.decision_symbol_mismatch'];
        }
        if ($bundle === 'position' && $field === 'field_mode') {
          $expected[] = ['field_decision', 'meridian.position.decision_mode_mismatch'];
        }
        $this->assertViolations($loaded, $expected, "$bundle: $field changed");
      }
    }
  }

  /**
   * The source version never decreases and is compared with the stored value.
   */
  public function testSourceVersionNeverDecreases(): void {
    foreach (['daily_run', 'decision', 'position', 'price_snapshot'] as $bundle) {
      $record = $this->record($bundle, ['field_source_version' => 5]);
      if ($bundle !== 'daily_run' && $bundle !== 'decision') {
        $this->assertValid($record, "$bundle: created with a version");
      }
      $record = $this->savedBaseline($bundle);
      $record->set('field_source_version', 5);
      $record->save();
      $loaded = Node::load($record->id());
      $this->assertValid($loaded, "$bundle: equal version");
      $loaded->set('field_source_version', 6);
      $this->assertValid($loaded, "$bundle: higher version");
      $loaded->set('field_source_version', 4);
      $this->assertRejected($loaded, 'field_source_version', 'meridian.non_decreasing', "$bundle: lower version");
      $loaded->setNewRevision(TRUE);
      $this->assertRejected($loaded, 'field_source_version', 'meridian.non_decreasing', "$bundle: lower version, new revision");
    }
    $first = $this->record('daily_run', ['field_external_id' => 'run-2026-10-05', 'field_trade_date' => '2026-10-05', 'field_source_version' => 1]);
    $first->save();
    $this->assertValid($first, 'created with version 1');
  }

  /**
   * A stale in-memory copy cannot bypass the rules (loadUnchanged).
   */
  public function testStaleCopyIsComparedWithTheStoredRecord(): void {
    $record = $this->record('daily_run', ['field_source_version' => 5]);
    $record->save();
    $stale = Node::load($record->id());
    $fresh = Node::load($record->id());
    $fresh->set('field_source_version', 8);
    $fresh->save();
    // The stale copy still holds version 5 in memory, but the database has 8.
    $stale->set('field_source_version', 6);
    $this->assertRejected($stale, 'field_source_version', 'meridian.non_decreasing', 'stale copy below the stored version');
    $stale->set('field_source_version', 8);
    $this->assertValid($stale, 'stale copy at the stored version');
  }

}
