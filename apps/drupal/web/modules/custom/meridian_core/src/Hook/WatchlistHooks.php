<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Hook;

use Drupal\Core\Hook\Attribute\Hook;
use Drupal\meridian_core\Service\WatchlistExternalId;
use Drupal\node\NodeInterface;

/**
 * Derives the Watchlist Item external ID (KD-5).
 */
class WatchlistHooks {

  /**
   * Creates the hooks.
   */
  public function __construct(protected WatchlistExternalId $externalId) {
  }

  /**
   * Implements hook_node_create().
   */
  #[Hook('node_create')]
  public function nodeCreate(NodeInterface $node): void {
    $this->externalId->derive($node);
  }

  /**
   * Implements hook_node_presave().
   */
  #[Hook('node_presave')]
  public function nodePresave(NodeInterface $node): void {
    $this->externalId->derive($node);
  }

}
