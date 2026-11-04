<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Hook;

use Drupal\Core\Entity\EntityTypeInterface;
use Drupal\Core\Hook\Attribute\Hook;
use Drupal\meridian_core\Validation\Patterns;

/**
 * Attaches the Meridian validation rules in code (KD-3).
 *
 * Rules that cannot be expressed as field settings (patterns, JSON documents,
 * decimal scale, uniqueness, immutability) are attached to the field
 * definitions of the five bundles. Cross-field rules are entity constraints.
 */
class FieldConstraintHooks {

  /**
   * The bundles of the content model.
   */
  public const BUNDLES = ['decision', 'position', 'daily_run', 'price_snapshot', 'watchlist_item'];

  /**
   * The bundles that are ingested and carry source_version and payload_hash.
   */
  protected const INGESTED = ['decision', 'position', 'daily_run', 'price_snapshot'];

  /**
   * Patterns by field name, the same on every bundle that has the field.
   */
  protected const PATTERNS = [
    'field_symbol' => Patterns::SYMBOL,
    'field_rule_version' => Patterns::VERSION_LABEL,
    'field_prompt_version' => Patterns::VERSION_LABEL,
    'field_model_name' => Patterns::MODEL_NAME,
    'field_payload_hash' => Patterns::PAYLOAD_HASH,
    'field_run_id' => Patterns::UUID,
  ];

  /**
   * Implements hook_entity_bundle_field_info_alter().
   *
   * @param array<string, \Drupal\Core\Field\FieldDefinitionInterface> $fields
   *   The bundle field definitions.
   * @param \Drupal\Core\Entity\EntityTypeInterface $entity_type
   *   The entity type.
   * @param string $bundle
   *   The bundle.
   */
  #[Hook('entity_bundle_field_info_alter')]
  public function bundleFieldInfoAlter(array &$fields, EntityTypeInterface $entity_type, string $bundle): void {
    if ($entity_type->id() !== 'node' || !in_array($bundle, self::BUNDLES, TRUE)) {
      return;
    }
    foreach ($this->constraintsFor($bundle) as $name => $constraints) {
      if (!isset($fields[$name])) {
        continue;
      }
      // Work on a copy, so the shared config entity is never changed.
      $field = clone $fields[$name];
      foreach ($constraints as [$plugin, $options]) {
        $field->addConstraint($plugin, $options);
      }
      $fields[$name] = $field;
    }
    foreach ($fields as $name => $field) {
      $extra = $this->settingConstraints($field);
      if ($extra) {
        $copy = clone $field;
        foreach ($extra as [$plugin, $options]) {
          $copy->addConstraint($plugin, $options);
        }
        $fields[$name] = $copy;
      }
    }
  }

  /**
   * Implements hook_entity_type_alter().
   *
   * @param \Drupal\Core\Entity\EntityTypeInterface[] $entity_types
   *   The entity types.
   */
  #[Hook('entity_type_alter')]
  public function entityTypeAlter(array &$entity_types): void {
    if (!isset($entity_types['node'])) {
      return;
    }
    foreach ([
      'MeridianExternalIdMatches',
      'MeridianDecisionRules',
      'MeridianPositionRules',
      'MeridianDailyRunRules',
      'MeridianPriceSnapshotRules',
      'MeridianWatchlistItemRules',
    ] as $constraint) {
      $entity_types['node']->addConstraint($constraint);
    }
  }

  /**
   * Returns the constraints by field name for a bundle.
   *
   * @return array<string, list<array{0: string, 1: array<string, mixed>}>>
   *   Pairs of plugin ID and options, by field name.
   */
  protected function constraintsFor(string $bundle): array {
    $map = [];
    foreach (self::PATTERNS as $field => $pattern) {
      $map[$field][] = ['MeridianPattern', ['pattern' => $pattern]];
    }
    $map['field_external_id'][] = ['MeridianPattern', ['pattern' => Patterns::EXTERNAL_ID_BY_BUNDLE[$bundle]]];
    $map['field_external_id'][] = ['MeridianUniqueInBundle', NULL];
    $map['field_external_id'][] = ['MeridianImmutable', NULL];
    if ($bundle === 'watchlist_item') {
      $map['field_symbol'][] = ['MeridianUniqueInBundle', NULL];
      $map['field_symbol'][] = ['MeridianImmutable', NULL];
      $map['field_notes'][] = ['MeridianMaxLength', ['max' => 500]];
      $map['field_modes'][] = ['MeridianNoDuplicateValues', NULL];
    }
    if (in_array($bundle, self::INGESTED, TRUE)) {
      $map['field_source_version'][] = ['MeridianNonDecreasing', NULL];
    }
    if ($bundle === 'decision') {
      $map['field_trade_date'][] = ['MeridianDateNotAfterToday', NULL];
      $map['field_rule_hits'][] = ['MeridianPattern', ['pattern' => Patterns::RULE_ID]];
      $map['field_rule_hits'][] = ['Count', ['max' => 50]];
      $map['field_inputs_snapshot'][] = ['MeridianJsonDocument', ['objectOnly' => TRUE, 'maxBytes' => 65536]];
      $map['field_raw_llm_output'][] = ['MeridianJsonDocument', ['objectOnly' => TRUE, 'maxBytes' => 32768]];
      $map['field_llm_rationale'][] = ['MeridianMaxLength', ['max' => 2000]];
    }
    return $map;
  }

  /**
   * Returns the constraints that follow from a field's own settings.
   *
   * Decimal fields get the scale rule from their storage precision and scale.
   * Fields with the meridian_core.allowed_values setting get the bundle rule.
   *
   * @return list<array{0: string, 1: array<string, mixed>|null}>
   *   Pairs of plugin ID and options.
   */
  protected function settingConstraints(object $field): array {
    $constraints = [];
    if ($field->getType() === 'decimal') {
      $storage = $field->getFieldStorageDefinition();
      $constraints[] = ['MeridianDecimalScale', [
        'precision' => (int) $storage->getSetting('precision'),
        'scale' => (int) $storage->getSetting('scale'),
        // A field with a Range maximum reports big values there already.
        'integerDigits' => (string) ($field->getSetting('max') ?? '') === '',
      ],
      ];
    }
    if (is_array($field->getThirdPartySetting('meridian_core', 'allowed_values'))) {
      $constraints[] = ['MeridianBundleAllowedValues', NULL];
    }
    return $constraints;
  }

}
