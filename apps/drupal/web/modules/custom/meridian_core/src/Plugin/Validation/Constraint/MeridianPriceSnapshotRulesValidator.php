<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\meridian_core\Validation\BundleRulesValidatorBase;
use Drupal\meridian_core\Validation\Decimals;
use Drupal\node\NodeInterface;

/**
 * Validates MeridianPriceSnapshotRules (OHLC consistency).
 */
class MeridianPriceSnapshotRulesValidator extends BundleRulesValidatorBase {

  /**
   * {@inheritdoc}
   */
  protected function bundle(): string {
    return 'price_snapshot';
  }

  /**
   * {@inheritdoc}
   */
  protected function check(NodeInterface $node): void {
    $open = $this->positive($node, 'field_open');
    $close = $this->positive($node, 'field_close');
    $low = $this->positive($node, 'field_low');
    $high = $this->decimal($node, 'field_high');

    // At most one violation per field: the first failing comparison.
    foreach (['open' => $open, 'close' => $close] as $name => $other) {
      if ($low !== NULL && $other !== NULL && Decimals::compare($low, $other) === 1) {
        $this->fail('field_low', 'meridian.price_snapshot.low_above_' . $name, 'The low must not be above the @name.', ['@name' => $name]);
        break;
      }
    }
    if ($high === NULL) {
      return;
    }
    foreach (['low' => $low, 'open' => $open, 'close' => $close] as $name => $other) {
      if ($other !== NULL && Decimals::compare($high, $other) === -1) {
        $this->fail('field_high', 'meridian.price_snapshot.high_below_' . $name, 'The high must not be below the @name.', ['@name' => $name]);
        break;
      }
    }
  }

}
