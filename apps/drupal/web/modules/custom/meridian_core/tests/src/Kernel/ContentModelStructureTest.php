<?php

declare(strict_types=1);

// phpcs:disable Drupal.Arrays.Array.LongLineDeclaration -- T09: one test case per line

namespace Drupal\Tests\meridian_core\Kernel;

use Drupal\Core\Config\FileStorage;
use Drupal\Core\Database\Database;
use Drupal\field\Entity\FieldConfig;
use Drupal\field\Entity\FieldStorageConfig;
use Drupal\node\Entity\Node;
use Drupal\node\Entity\NodeType;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\RunTestsInSeparateProcesses;

/**
 * The shipped content model equals the amended data model (TC-T09-03 to 07).
 *
 * The expected table below is written from docs/specs/data-model.md and is
 * compared with config/sync, field by field, so a missing, extra or changed
 * field fails the test and names the bundle and the field.
 */
#[Group('meridian_core')]
#[RunTestsInSeparateProcesses]
class ContentModelStructureTest extends MeridianKernelTestBase {

  /**
   * Builds a field spec.
   *
   * @param string $type
   *   The field type.
   * @param bool $required
   *   Whether the field is required.
   * @param array<string, mixed> $storage
   *   Expected storage settings (a subset).
   * @param array<string, mixed> $instance
   *   Expected instance settings (a subset).
   * @param int $cardinality
   *   The cardinality.
   * @param bool $indexed
   *   Whether the data model says "Indexed: yes".
   *
   * @return array<string, mixed>
   *   The spec.
   */
  protected function spec(string $type, bool $required, array $storage = [], array $instance = [], int $cardinality = 1, bool $indexed = FALSE): array {
    return compact('type', 'required', 'storage', 'instance', 'cardinality', 'indexed');
  }

  /**
   * A string field.
   *
   * @param bool $r
   *   Required.
   * @param int $len
   *   The maximum length.
   * @param bool $ix
   *   Indexed.
   * @param int $card
   *   The cardinality.
   *
   * @return array<string, mixed>
   *   The spec.
   */
  protected function str(bool $r, int $len, bool $ix = FALSE, int $card = 1): array {
    return $this->spec('string', $r, ['max_length' => $len], [], $card, $ix);
  }

  /**
   * A decimal field.
   *
   * @return array<string, mixed>
   *   The spec.
   */
  protected function dec(bool $r, int $p, int $s, ?string $min = NULL, ?string $max = NULL, bool $ix = FALSE): array {
    $instance = array_filter(['min' => $min, 'max' => $max], static fn ($v) => $v !== NULL);
    return $this->spec('decimal', $r, ['precision' => $p, 'scale' => $s], $instance, 1, $ix);
  }

  /**
   * An integer field.
   *
   * @param bool $r
   *   Required.
   * @param string|null $min
   *   The minimum.
   * @param string|null $max
   *   The maximum.
   * @param string $size
   *   The storage size.
   * @param bool $ix
   *   Indexed.
   *
   * @return array<string, mixed>
   *   The spec.
   */
  protected function int(bool $r, ?string $min = NULL, ?string $max = NULL, string $size = 'normal', bool $ix = FALSE): array {
    $instance = array_filter(['min' => $min, 'max' => $max], static fn ($v) => $v !== NULL);
    return $this->spec('integer', $r, ['size' => $size], $instance, 1, $ix);
  }

  /**
   * A list field with allowed values.
   *
   * @param bool $r
   *   Required.
   * @param string[] $values
   *   The allowed values, in order.
   * @param bool $ix
   *   Indexed.
   * @param int $card
   *   The cardinality.
   *
   * @return array<string, mixed>
   *   The spec.
   */
  protected function list(bool $r, array $values, bool $ix = FALSE, int $card = 1): array {
    return $this->spec('list_string', $r, ['allowed_values' => $values], [], $card, $ix);
  }

  /**
   * A date-only field.
   *
   * @return array<string, mixed>
   *   The spec.
   */
  protected function date(bool $r, bool $ix = FALSE): array {
    return $this->spec('datetime', $r, ['datetime_type' => 'date'], [], 1, $ix);
  }

  /**
   * A reference to a node bundle.
   *
   * @return array<string, mixed>
   *   The spec.
   */
  protected function ref(string $bundle): array {
    return $this->spec('entity_reference', TRUE, ['target_type' => 'node'], ['handler' => 'default:node', 'target_bundles' => [$bundle]], 1, TRUE);
  }

  /**
   * The expected model: bundle => field name (without field_) => spec.
   *
   * @return array<string, array<string, array<string, mixed>>>
   *   The table.
   */
  protected function expectedModel(): array {
    $mode = ['long', 'short'];
    $action = ['BUY', 'AVOID'];
    $status = ['open', 'closed', 'success', 'failed', 'skipped'];
    $common = fn (bool $ix = TRUE): array => [
      'external_id' => $this->str(TRUE, 64, $ix),
      'source_version' => $this->int(TRUE, '1'),
      'payload_hash' => $this->str(TRUE, 64),
    ];
    return [
      'decision' => $common() + [
        'trade_date' => $this->date(TRUE, TRUE),
        'symbol' => $this->str(TRUE, 20, TRUE),
        'mode' => $this->list(TRUE, $mode, TRUE),
        'score' => $this->dec(TRUE, 5, 2, '0', '100', TRUE),
        'pre_llm_action' => $this->list(TRUE, $action),
        'action' => $this->list(TRUE, $action, TRUE),
        'vetoed' => $this->spec('boolean', TRUE, [], [], 1, TRUE),
        'veto_reason' => $this->list(FALSE, ['llm_veto', 'malformed', 'empty', 'timeout', 'api_error', 'schema_violation', 'budget']),
        'rule_hits' => $this->str(FALSE, 32, FALSE, -1),
        'rule_version' => $this->str(TRUE, 32),
        'prompt_version' => $this->str(TRUE, 32),
        'model_name' => $this->str(TRUE, 64),
        'inputs_snapshot' => $this->spec('string_long', TRUE),
        'raw_llm_output' => $this->spec('string_long', TRUE),
        'llm_rationale' => $this->spec('string_long', FALSE),
        'close_price' => $this->dec(TRUE, 14, 4, '0.0001'),
        'run' => $this->ref('daily_run'),
      ],
      'position' => $common() + [
        'symbol' => $this->str(TRUE, 20, TRUE),
        'mode' => $this->list(TRUE, $mode, TRUE),
        'status' => $this->list(TRUE, $status, TRUE),
        'entry_date' => $this->date(TRUE, TRUE),
        'entry_price' => $this->dec(TRUE, 14, 4, '0.0001'),
        'quantity' => $this->int(TRUE, '1'),
        'stop_price' => $this->dec(TRUE, 14, 4, '0.0001'),
        'target_price' => $this->dec(TRUE, 14, 4, '0.0001'),
        'time_stop_date' => $this->date(FALSE),
        'exit_date' => $this->date(FALSE, TRUE),
        'exit_price' => $this->dec(FALSE, 14, 4, '0.0001'),
        'exit_reason' => $this->list(FALSE, ['stop', 'gap_stop', 'target', 'time_stop']),
        'costs_total' => $this->dec(TRUE, 12, 2, '0'),
        'realised_pnl' => $this->dec(FALSE, 14, 2),
        'unrealised_pnl' => $this->dec(FALSE, 14, 2),
        'last_mark_price' => $this->dec(FALSE, 14, 4, '0.0001'),
        'last_mark_date' => $this->date(FALSE),
        'r_multiple' => $this->dec(FALSE, 8, 3, '-100', '100'),
        'run' => $this->ref('daily_run'),
        'decision' => $this->ref('decision'),
      ],
      'daily_run' => $common() + [
        'trade_date' => $this->date(TRUE, TRUE),
        'run_id' => $this->str(TRUE, 36),
        'attempt' => $this->int(TRUE, '1'),
        'status' => $this->list(TRUE, $status, TRUE),
        'skip_reason' => $this->str(FALSE, 255),
        'watchlist_source' => $this->list(FALSE, ['drupal', 'snapshot', 'seed']),
        'symbols_total' => $this->int(TRUE, '0', '50'),
        'decisions_count' => $this->int(TRUE, '0'),
        'buy_count' => $this->int(TRUE, '0'),
        'veto_count' => $this->int(TRUE, '0'),
        'failure_count' => $this->int(TRUE, '0'),
        'virtual_equity' => $this->dec(FALSE, 16, 2, '0.01'),
        'llm_cost_usd' => $this->dec(TRUE, 10, 4, '0'),
        'rule_version' => $this->str(TRUE, 32),
        'prompt_version' => $this->str(TRUE, 32),
        'model_name' => $this->str(TRUE, 64),
        'started_at' => $this->spec('timestamp', TRUE),
        'finished_at' => $this->spec('timestamp', FALSE, [], [], 1, TRUE),
      ],
      'price_snapshot' => $common() + [
        'trade_date' => $this->date(TRUE, TRUE),
        'symbol' => $this->str(TRUE, 20, TRUE),
        'open' => $this->dec(TRUE, 14, 4, '0.0001'),
        'high' => $this->dec(TRUE, 14, 4),
        'low' => $this->dec(TRUE, 14, 4, '0.0001'),
        'close' => $this->dec(TRUE, 14, 4, '0.0001'),
        'volume' => $this->int(TRUE, '0', NULL, 'big'),
        'adjusted' => $this->spec('boolean', TRUE),
        'source' => $this->list(TRUE, ['yfinance', 'stub']),
      ],
      'watchlist_item' => [
        'external_id' => $this->str(TRUE, 64, TRUE),
        'symbol' => $this->str(TRUE, 20, TRUE),
        'enabled' => $this->spec('boolean', TRUE, [], [], 1, TRUE),
        'modes' => $this->list(TRUE, $mode, FALSE, 2),
        'sort_order' => $this->int(TRUE, '0', '999', 'normal', TRUE),
        'notes' => $this->spec('string_long', FALSE),
      ],
    ];
  }

  /**
   * Reads the columns that start an index of a table.
   *
   * @return string[]
   *   The column names.
   */
  protected function indexedColumns(string $table): array {
    $rows = Database::getConnection()->query("SHOW INDEX FROM {{$table}}")->fetchAll();
    $columns = [];
    foreach ($rows as $row) {
      if ((int) $row->Seq_in_index === 1) {
        $columns[] = $row->Column_name;
      }
    }
    return $columns;
  }

  /**
   * Tests that a subset of settings matches the settings of a field.
   *
   * @param array<string, mixed> $expected
   *   The expected settings.
   * @param array<string, mixed> $actual
   *   The actual settings.
   * @param string $label
   *   The bundle and field, shown on failure.
   */
  protected function assertSettings(array $expected, array $actual, string $label): void {
    foreach ($expected as $key => $value) {
      if ($key === 'allowed_values') {
        $this->assertSame($value, array_map('strval', array_keys($actual['allowed_values'])), "$label allowed_values");
      }
      elseif ($key === 'target_bundles') {
        $this->assertSame($value, array_values($actual['handler_settings']['target_bundles']), "$label target_bundles");
      }
      elseif ($key === 'min' || $key === 'max') {
        $this->assertEquals((float) $value, (float) $actual[$key], "$label $key");
        $this->assertNotSame('', (string) $actual[$key], "$label $key set");
      }
      else {
        $this->assertSame($value, $actual[$key], "$label $key");
      }
    }
  }

  /**
   * Every bundle has exactly the fields of the data model (AC1).
   */
  public function testBundlesAndFieldsEqualTheDataModel(): void {
    $expected_model = $this->expectedModel();
    $this->assertSame(array_keys($expected_model), array_values(array_intersect(array_keys($expected_model), array_keys(NodeType::loadMultiple()))));
    $this->assertCount(5, NodeType::loadMultiple(), 'exactly five node types');
    foreach ($expected_model as $bundle => $fields) {
      $type = NodeType::load($bundle);
      $this->assertTrue($type->shouldCreateNewRevision(), "$bundle new_revision");
      $this->assertFalse($type->displaySubmitted(), "$bundle display_submitted");
      $this->assertSame(0, (int) $type->get('preview_mode'), "$bundle preview_mode");
      $this->assertSame(['meridian_core'], $type->get('dependencies')['enforced']['module'], "$bundle owned by meridian_core");
      $this->assertTrue(Node::create(['type' => $bundle, 'title' => 'x'])->isPublished(), "$bundle published by default");

      $actual = array_keys(FieldConfig::loadMultiple(array_map(static fn (string $f): string => "node.$bundle.field_$f", array_keys($fields))));
      $this->assertCount(count($fields), $actual, "$bundle: every expected field exists");
      $all = $this->container->get('entity_type.manager')->getStorage('field_config')
        ->loadByProperties(['entity_type' => 'node', 'bundle' => $bundle]);
      $names = array_map(static fn (FieldConfig $f): string => $f->getName(), $all);
      sort($names);
      $wanted = array_map(static fn (string $f): string => "field_$f", array_keys($fields));
      sort($wanted);
      $this->assertSame($wanted, $names, "$bundle: no extra and no missing field");

      foreach ($fields as $name => $spec) {
        $label = "$bundle.field_$name";
        $field = FieldConfig::load("node.$bundle.field_$name");
        $storage = FieldStorageConfig::loadByName('node', "field_$name");
        $this->assertSame($spec['type'], $field->getType(), "$label type");
        $this->assertSame($spec['required'], $field->isRequired(), "$label required");
        $this->assertSame($spec['cardinality'], $storage->getCardinality(), "$label cardinality");
        $this->assertSettings($spec['storage'], $storage->getSettings(), "$label storage");
        $this->assertSettings($spec['instance'], $field->getSettings(), "$label instance");
      }
      $this->assertSame(1, (int) $this->container->get('config.factory')->get("node.type.$bundle")->get('new_revision'));
    }
  }

  /**
   * Shared field_status: union on the storage, subset per bundle (DN-3).
   */
  public function testStatusUnionAndSubsets(): void {
    $storage = FieldStorageConfig::loadByName('node', 'field_status');
    $this->assertSame(['open', 'closed', 'success', 'failed', 'skipped'], array_map('strval', array_keys($storage->getSetting('allowed_values'))));
    $this->assertSame(['open', 'closed'], FieldConfig::load('node.position.field_status')->getThirdPartySetting('meridian_core', 'allowed_values'));
    $this->assertSame(['success', 'failed', 'skipped'], FieldConfig::load('node.daily_run.field_status')->getThirdPartySetting('meridian_core', 'allowed_values'));
    foreach ($this->expectedModel() as $bundle => $fields) {
      foreach (array_keys($fields) as $name) {
        if ($name !== 'status') {
          $this->assertNull(FieldConfig::load("node.$bundle.field_$name")->getThirdPartySetting('meridian_core', 'allowed_values'), "$bundle.$name has no subset");
        }
      }
    }
  }

  /**
   * Every "Indexed: yes" column has an index (TC-T09-05).
   */
  public function testIndexedColumns(): void {
    foreach ($this->expectedModel() as $bundle => $fields) {
      foreach ($fields as $name => $spec) {
        if (!$spec['indexed']) {
          continue;
        }
        $column = $spec['type'] === 'entity_reference' ? "field_{$name}_target_id" : "field_{$name}_value";
        $this->assertContains($column, $this->indexedColumns("node__field_$name"), "$bundle.field_$name is indexed");
      }
    }
  }

  /**
   * The default displays list every field, and nothing else is shipped.
   */
  public function testDisplaysCoverEveryField(): void {
    $source = new FileStorage($this->syncDirectory());
    foreach ($this->expectedModel() as $bundle => $fields) {
      foreach (['form', 'view'] as $kind) {
        $display = $source->read("core.entity_{$kind}_display.node.$bundle.default");
        $this->assertIsArray($display, "$bundle $kind display exists");
        $listed = array_merge(array_keys($display['content']), array_keys($display['hidden'] ?? []));
        foreach (array_keys($fields) as $name) {
          $this->assertContains("field_$name", $listed, "$bundle $kind display lists field_$name");
        }
      }
    }
    $this->assertCount(5, $source->listAll('core.entity_form_display.node.'));
    $this->assertCount(5, $source->listAll('core.entity_view_display.node.'));
    $this->assertSame([], $source->listAll('views.view.'), 'no Views in T09');
    $this->assertSame([], $source->listAll('jsonapi'), 'no JSON:API config in T09');
  }

}
