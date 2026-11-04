<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\Core\Validation\Attribute\Constraint;
use Symfony\Component\Validator\Constraint as SymfonyConstraint;

/**
 * Cross-field rules of the watchlist_item content type.
 *
 * The violation codes are meridian.watchlist_item.*, set by the validator.
 */
#[Constraint(
  id: 'MeridianWatchlistItemRules',
  label: new TranslatableMarkup('Meridian WatchlistItem rules', [], ['context' => 'Validation'])
)]
class MeridianWatchlistItemRules extends SymfonyConstraint {

}
