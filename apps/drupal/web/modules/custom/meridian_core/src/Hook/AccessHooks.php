<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Hook;

use Drupal\Core\Access\AccessResult;
use Drupal\Core\Access\AccessResultInterface;
use Drupal\Core\Field\FieldDefinitionInterface;
use Drupal\Core\Field\FieldItemListInterface;
use Drupal\Core\Hook\Attribute\Hook;
use Drupal\Core\Session\AccountInterface;
use Drupal\node\NodeInterface;

/**
 * Entity and field access of the five bundles (KD-7, design D6).
 *
 * The hooks return forbidden or neutral, never allowed. Neutral keeps core's
 * published check, so an unpublished record stays hidden. Administrators pass
 * through the bypass node access permission. The hooks do not filter entity
 * queries or Views (core does that only with hook_node_grants), so each View
 * sets its own access permission (T12).
 */
class AccessHooks {

  /**
   * The permission to view a Watchlist Item.
   */
  protected const WATCHLIST_VIEW = 'view meridian watchlist';

  /**
   * The permission to view the other four bundles.
   */
  protected const RECORDS_VIEW = 'view meridian records';

  /**
   * The permission of the ingest bookkeeping fields.
   */
  protected const ADMINISTER = 'administer meridian records';

  /**
   * The permission of the inputs, cost, source and notes fields.
   */
  protected const INPUTS = 'view meridian inputs';

  /**
   * The permission of the raw LLM output.
   */
  protected const RAW_OUTPUT = 'view meridian raw llm output';

  /**
   * Field view permissions by bundle and field name.
   */
  protected const FIELD_PERMISSIONS = [
    'decision' => [
      'field_raw_llm_output' => self::RAW_OUTPUT,
      'field_inputs_snapshot' => self::INPUTS,
      'field_source_version' => self::ADMINISTER,
      'field_payload_hash' => self::ADMINISTER,
    ],
    'position' => [
      'field_source_version' => self::ADMINISTER,
      'field_payload_hash' => self::ADMINISTER,
    ],
    'daily_run' => [
      'field_llm_cost_usd' => self::INPUTS,
      'field_source_version' => self::ADMINISTER,
      'field_payload_hash' => self::ADMINISTER,
    ],
    'price_snapshot' => [
      'field_source' => self::INPUTS,
      'field_source_version' => self::ADMINISTER,
      'field_payload_hash' => self::ADMINISTER,
    ],
    'watchlist_item' => [
      'field_notes' => self::INPUTS,
    ],
  ];

  /**
   * Implements hook_node_access().
   */
  #[Hook('node_access')]
  public function nodeAccess(NodeInterface $node, string $operation, AccountInterface $account): AccessResultInterface {
    $bundle = $node->bundle();
    if (!isset(self::FIELD_PERMISSIONS[$bundle])) {
      return AccessResult::neutral();
    }
    if ($operation === 'view') {
      $permission = $bundle === 'watchlist_item' ? self::WATCHLIST_VIEW : self::RECORDS_VIEW;
      return AccessResult::forbiddenIf(!$account->hasPermission($permission))->cachePerPermissions();
    }
    if ($operation === 'update' || $operation === 'delete') {
      return AccessResult::forbiddenIf(!$account->hasPermission('bypass node access'))->cachePerPermissions();
    }
    return AccessResult::neutral()->cachePerPermissions();
  }

  /**
   * Implements hook_node_create_access().
   *
   * @param \Drupal\Core\Session\AccountInterface $account
   *   The account.
   * @param array<string, mixed> $context
   *   The creation context.
   * @param string|null $entity_bundle
   *   The bundle.
   */
  #[Hook('node_create_access')]
  public function nodeCreateAccess(AccountInterface $account, array $context, ?string $entity_bundle): AccessResultInterface {
    if ($entity_bundle === NULL || !isset(self::FIELD_PERMISSIONS[$entity_bundle])) {
      return AccessResult::neutral();
    }
    return AccessResult::forbiddenIf(!$account->hasPermission('bypass node access'))->cachePerPermissions();
  }

  /**
   * Implements hook_entity_field_access().
   *
   * @param string $operation
   *   The operation.
   * @param \Drupal\Core\Field\FieldDefinitionInterface $field_definition
   *   The field definition.
   * @param \Drupal\Core\Session\AccountInterface $account
   *   The account.
   * @param \Drupal\Core\Field\FieldItemListInterface<\Drupal\Core\Field\FieldItemInterface>|null $items
   *   The items, when known.
   */
  #[Hook('entity_field_access')]
  public function fieldAccess(string $operation, FieldDefinitionInterface $field_definition, AccountInterface $account, ?FieldItemListInterface $items = NULL): AccessResultInterface {
    if ($operation !== 'view' || $field_definition->getTargetEntityTypeId() !== 'node') {
      return AccessResult::neutral();
    }
    $permission = self::FIELD_PERMISSIONS[$field_definition->getTargetBundle() ?? ''][$field_definition->getName()] ?? NULL;
    if ($permission === NULL) {
      return AccessResult::neutral();
    }
    return AccessResult::forbiddenIf(!$account->hasPermission($permission))->cachePerPermissions();
  }

}
