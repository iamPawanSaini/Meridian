<?php

declare(strict_types=1);

namespace Drupal\Tests\meridian_core\Kernel;

use Drupal\node\Entity\Node;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\RunTestsInSeparateProcesses;

/**
 * Every validation rule of the Watchlist Item bundle (TC-T09-24, 25 and 33).
 */
#[Group('meridian_core')]
#[RunTestsInSeparateProcesses]
class WatchlistItemValidationTest extends MeridianKernelTestBase {

  /**
   * Field rules (TC-T09-24).
   */
  public function testFieldRules(): void {
    $this->assertValid($this->record('watchlist_item'), 'baseline');
    $cases = [];
    foreach (['title', 'field_symbol', 'field_enabled', 'field_modes', 'field_sort_order'] as $field) {
      $cases["$field missing"] = [[$field => NULL], [[$field, self::REQUIRED]]];
    }
    $cases['symbol lowercase'] = [['field_symbol' => 'reliance'], [['field_symbol', 'meridian.pattern']]];
    $cases['symbol 21 characters'] = [['field_symbol' => str_repeat('A', 21)], [['field_symbol', self::TOO_LONG]]];
    $cases['symbol 20 characters'] = [['field_symbol' => str_repeat('A', 20), 'field_external_id' => 'wl-' . str_repeat('A', 20)], []];
    foreach ([['long'], ['short'], ['long', 'short']] as $modes) {
      $cases['modes ' . implode(',', $modes)] = [['field_modes' => $modes], []];
    }
    $cases['modes long,long'] = [['field_modes' => ['long', 'long']], [['field_modes', 'meridian.duplicate_value']]];
    $cases['modes long,flat'] = [['field_modes' => ['long', 'flat']], [['field_modes.1', self::NOT_ALLOWED]]];
    $cases['modes 3 values'] = [
      ['field_modes' => ['long', 'short', 'long']],
      [['field_modes', self::TOO_MANY], ['field_modes', 'meridian.duplicate_value']],
    ];
    $cases['sort_order -1'] = [['field_sort_order' => -1], [['field_sort_order', self::TOO_LOW]]];
    $cases['sort_order 0'] = [['field_sort_order' => 0], []];
    $cases['sort_order 999'] = [['field_sort_order' => 999], []];
    $cases['sort_order 1000'] = [['field_sort_order' => 1000], [['field_sort_order', self::TOO_HIGH]]];
    $cases['notes 500 characters'] = [['field_notes' => str_repeat('a', 500)], []];
    $cases['notes 501 characters'] = [['field_notes' => str_repeat('a', 501)], [['field_notes', 'meridian.max_length']]];
    $cases['enabled false'] = [['field_enabled' => 0], []];
    $cases['title 255'] = [['title' => str_repeat('a', 255)], []];
    $cases['title 256'] = [['title' => str_repeat('a', 256)], [['title', self::TOO_LONG]]];
    $this->runCases('watchlist_item', $cases);
    $new = Node::create(['type' => 'watchlist_item', 'title' => 'x', 'field_symbol' => 'TCS', 'field_modes' => ['long'], 'field_sort_order' => 1]);
    $this->assertSame('1', (string) $new->get('field_enabled')->value, 'enabled defaults to true');
  }

  /**
   * The external ID is derived and checked (KD-5, TC-T09-25).
   */
  public function testExternalIdDerivation(): void {
    $values = ['type' => 'watchlist_item', 'title' => 'Tata', 'field_modes' => ['long'], 'field_sort_order' => 1];
    $created = Node::create($values + ['field_symbol' => 'TCS']);
    $this->assertSame('wl-TCS', $created->get('field_external_id')->value, 'derived on node_create');
    $this->assertValid($created, 'derived id is valid');

    $created = Node::create($values + ['field_symbol' => 'INFY']);
    $created->set('field_external_id', NULL);
    $created->save();
    $this->assertSame('wl-INFY', $created->get('field_external_id')->value, 'derived on node_presave');

    $supplied = Node::create($values + ['field_symbol' => 'WIPRO', 'field_external_id' => 'wl-OTHER']);
    $this->assertSame('wl-OTHER', $supplied->get('field_external_id')->value, 'a supplied id is kept');
    $this->assertRejected($supplied, 'field_external_id', 'meridian.external_id_mismatch', 'supplied id differs');

    $service = $this->container->get('meridian_core.watchlist_external_id');
    $this->assertSame('wl-HDFC', $service->forSymbol('HDFC'));
    $bare = Node::create($values);
    $bare->set('field_symbol', 'ITC');
    $this->assertTrue($service->derive($bare));
    $this->assertSame('wl-ITC', $bare->get('field_external_id')->value);
    $this->assertFalse($service->derive($bare), 'an existing id is not replaced');
    $bad = Node::create($values + ['field_symbol' => 'bad symbol']);
    $this->assertNull($bad->get('field_external_id')->value, 'an invalid symbol is not used');
    $this->assertFalse($service->derive($this->record('decision')), 'other bundles are untouched');
  }

  /**
   * Symbol uniqueness and immutability (DN-8, TC-T09-25 and TC-T09-33).
   */
  public function testSymbolUniqueAndImmutable(): void {
    $saved = $this->record('watchlist_item');
    $saved->save();
    $this->assertRejected($this->record('watchlist_item'), 'field_symbol', 'meridian.unique_in_bundle', 'duplicate watchlist symbol: one violation');
    // A Decision with the same symbol does not collide with the Watchlist Item.
    $this->assertValid($this->record('decision', ['field_symbol' => 'RELIANCE']), 'decision with the same symbol');
    $this->assertValid($this->record('watchlist_item', ['field_symbol' => 'TCS', 'field_external_id' => 'wl-TCS']), 'another symbol');

    $loaded = Node::load($saved->id());
    $loaded->set('field_symbol', 'TCS');
    $this->assertRejected($loaded, 'field_symbol', 'meridian.immutable', 'symbol changed after creation');
    $loaded = Node::load($saved->id());
    $loaded->set('title', 'Renamed');
    $this->assertValid($loaded, 'title can change');
    $loaded->set('field_sort_order', 5);
    $this->assertValid($loaded, 'unchanged symbol');
  }

  /**
   * At most 50 enabled items (A-01, TC-T09-25).
   */
  public function testEnabledLimit(): void {
    $limit = [['field_enabled', 'meridian.watchlist_item.enabled_limit']];
    $enabled = [];
    for ($i = 1; $i <= 50; $i++) {
      $symbol = sprintf('SYM%02d', $i);
      $item = $this->record('watchlist_item', ['field_symbol' => $symbol, 'field_external_id' => "wl-$symbol", 'field_sort_order' => $i]);
      $item->save();
      $enabled[] = $item;
    }
    $this->assertRejected($this->record('watchlist_item', ['field_symbol' => 'EXTRA1', 'field_external_id' => 'wl-EXTRA1']), 'field_enabled', 'meridian.watchlist_item.enabled_limit', 'the 51st enabled item');
    $disabled = $this->record('watchlist_item', ['field_symbol' => 'EXTRA2', 'field_external_id' => 'wl-EXTRA2', 'field_enabled' => 0]);
    $this->assertValid($disabled, 'the 51st item, disabled');
    $disabled->save();
    $this->assertValid(Node::load($enabled[0]->id()), 're-save of an enabled item at 50');
    $again = Node::load($disabled->id());
    $again->set('field_enabled', 1);
    $this->assertViolations($again, $limit, 'enabling a 51st item by edit');
    $first = Node::load($enabled[0]->id());
    $first->set('field_enabled', 0);
    $this->assertValid($first, 'disabling an item');
    $first->save();
    $again = Node::load($disabled->id());
    $again->set('field_enabled', 1);
    $this->assertValid($again, 'enabling again once one item is disabled');
  }

}
