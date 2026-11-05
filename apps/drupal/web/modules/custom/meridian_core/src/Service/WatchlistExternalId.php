<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Service;

use Drupal\meridian_core\Validation\Patterns;
use Drupal\node\NodeInterface;

/**
 * Derives the Watchlist Item external ID from its symbol (KD-5).
 *
 * The admin form (T12) calls derive() from its entity builder before
 * validation, as the create and presave hooks do.
 */
class WatchlistExternalId {

  /**
   * The external ID of a symbol.
   */
  public function forSymbol(string $symbol): string {
    return 'wl-' . $symbol;
  }

  /**
   * Sets field_external_id of a watchlist item that has a symbol but no ID.
   *
   * A supplied ID is never overwritten, so the mismatch rule can reject it.
   * A symbol that is not valid is left alone, because the symbol rule reports
   * it.
   *
   * @return bool
   *   TRUE when the ID was set.
   */
  public function derive(NodeInterface $node): bool {
    if ($node->bundle() !== 'watchlist_item' || !$node->hasField('field_external_id')) {
      return FALSE;
    }
    $symbol = $node->get('field_symbol')->value;
    if ($node->get('field_external_id')->value !== NULL && $node->get('field_external_id')->value !== '') {
      return FALSE;
    }
    if (!Patterns::matches(Patterns::SYMBOL, $symbol)) {
      return FALSE;
    }
    $node->set('field_external_id', $this->forSymbol($symbol));
    return TRUE;
  }

}
