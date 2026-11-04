<?php

declare(strict_types=1);

namespace Drupal\Tests\meridian_core\Kernel;

use Drupal\KernelTests\KernelTestBase;
use Drupal\Tests\meridian_core\Traits\FixedTime;
use Drupal\Tests\meridian_core\Traits\MeridianRecordFactoryTrait;
use Drupal\Tests\meridian_core\Traits\SyncConfigTrait;
use Drupal\node\NodeInterface;
use Symfony\Component\DependencyInjection\ContainerBuilder;
use Symfony\Component\Validator\Constraints\Choice;
use Symfony\Component\Validator\Constraints\Count;
use Symfony\Component\Validator\Constraints\Length;
use Symfony\Component\Validator\Constraints\NotNull;
use Symfony\Component\Validator\Constraints\Range;

/**
 * Base of the Kernel tests: the shipped content model on MariaDB.
 *
 * Every test calls validate() on entities built in code. Violations are
 * compared as a list of (property path, code) pairs, exactly.
 */
abstract class MeridianKernelTestBase extends KernelTestBase {

  use SyncConfigTrait;
  use MeridianRecordFactoryTrait;

  /**
   * The code core gives to a missing required value.
   */
  protected const REQUIRED = NotNull::IS_NULL_ERROR;

  /**
   * The code core gives to a value outside the allowed list.
   */
  protected const NOT_ALLOWED = Choice::NO_SUCH_CHOICE_ERROR;

  /**
   * The code core gives to a value under the field minimum.
   */
  protected const TOO_LOW = Range::TOO_LOW_ERROR;

  /**
   * The code core gives to a value over the field maximum.
   */
  protected const TOO_HIGH = Range::TOO_HIGH_ERROR;

  /**
   * The code core gives to text longer than max_length.
   */
  protected const TOO_LONG = Length::TOO_LONG_ERROR;

  /**
   * The code core gives to a list with too many values.
   */
  protected const TOO_MANY = Count::TOO_MANY_ERROR;

  /**
   * {@inheritdoc}
   */
  protected static $modules = [
    'system',
    'user',
    'field',
    'text',
    'filter',
    'node',
    'options',
    'datetime',
    'meridian_core',
  ];

  /**
   * {@inheritdoc}
   */
  public function register(ContainerBuilder $container): void {
    parent::register($container);
    $container->getDefinition('datetime.time')
      ->setClass(FixedTime::class)
      ->setArguments([]);
  }

  /**
   * {@inheritdoc}
   */
  protected function setUp(): void {
    parent::setUp();
    FixedTime::$now = 1793793600;
    $this->installEntitySchema('user');
    $this->installEntitySchema('node');
    $this->installSchema('node', ['node_access']);
    $this->installSyncedConfig();
  }

  /**
   * Validates an entity and returns the (path, code) pairs, sorted.
   *
   * The path is the field machine name. The detail of a field-level violation
   * (".0.value", ".0.target_id") is removed, a delta of a multi-value field
   * stays ("field_rule_hits.2" and "field_modes.1").
   *
   * @return list<array{0: string, 1: string}>
   *   The violations.
   */
  protected function violationsOf(NodeInterface $node): array {
    $pairs = [];
    foreach ($node->validate() as $violation) {
      $path = $violation->getPropertyPath();
      if (preg_match('/^([a-z_]+)(?:\.(\d+))?(?:\.(?:value|target_id))?$/', $path, $m) === 1) {
        $keep_delta = in_array($m[1], ['field_rule_hits', 'field_modes'], TRUE) && isset($m[2]);
        $path = $keep_delta ? $m[1] . '.' . $m[2] : $m[1];
      }
      $pairs[] = [$path, (string) $violation->getCode()];
    }
    sort($pairs);
    return $pairs;
  }

  /**
   * Asserts the exact (path, code) list of an entity.
   *
   * @param \Drupal\node\NodeInterface $node
   *   The entity.
   * @param list<array{0: string, 1: string}> $expected
   *   The expected pairs. Empty means the entity is valid.
   * @param string $label
   *   The case, shown when the assertion fails.
   */
  protected function assertViolations(NodeInterface $node, array $expected, string $label): void {
    sort($expected);
    $this->assertSame($expected, $this->violationsOf($node), $label);
  }

  /**
   * Asserts one rejection: one violation at a path with a code.
   */
  protected function assertRejected(NodeInterface $node, string $path, string $code, string $label): void {
    $this->assertViolations($node, [[$path, $code]], $label);
  }

  /**
   * Asserts that an entity is valid.
   */
  protected function assertValid(NodeInterface $node, string $label): void {
    $this->assertViolations($node, [], $label);
  }

  /**
   * Runs rejection cases and accept cases of one bundle.
   *
   * @param string $bundle
   *   The bundle.
   * @param array<string, array{0: array<string, mixed>, 1: list<array{0: string, 1: string}>}> $cases
   *   Cases by label: field changes and the expected violations.
   */
  protected function runCases(string $bundle, array $cases): void {
    foreach ($cases as $label => [$changes, $expected]) {
      $this->assertViolations($this->record($bundle, $changes), $expected, $bundle . ': ' . $label);
    }
  }

}
