<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\DependencyInjection\ContainerInjectionInterface;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\meridian_core\Validation\BundleRulesValidatorBase;
use Drupal\node\NodeInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Validates MeridianWatchlistItemRules (A-01: at most 50 enabled items).
 */
final class MeridianWatchlistItemRulesValidator extends BundleRulesValidatorBase implements ContainerInjectionInterface {

  /**
   * The most enabled watchlist items (A-01).
   */
  public const MAX_ENABLED = 50;

  /**
   * Creates the validator.
   */
  public function __construct(protected EntityTypeManagerInterface $entityTypeManager) {
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container): static {
    return new static($container->get('entity_type.manager'));
  }

  /**
   * {@inheritdoc}
   */
  protected function bundle(): string {
    return 'watchlist_item';
  }

  /**
   * {@inheritdoc}
   */
  protected function check(NodeInterface $node): void {
    if ($this->flag($node, 'field_enabled') !== TRUE) {
      return;
    }
    $query = $this->entityTypeManager->getStorage('node')->getQuery()
      ->accessCheck(FALSE)
      ->condition('type', 'watchlist_item')
      ->condition('field_enabled.value', 1);
    if (!$node->isNew()) {
      $query->condition('nid', $node->id(), '<>');
    }
    if ((int) $query->count()->execute() >= self::MAX_ENABLED) {
      $this->fail('field_enabled', 'meridian.watchlist_item.enabled_limit', 'At most @max watchlist items can be enabled.', ['@max' => self::MAX_ENABLED]);
    }
  }

}
