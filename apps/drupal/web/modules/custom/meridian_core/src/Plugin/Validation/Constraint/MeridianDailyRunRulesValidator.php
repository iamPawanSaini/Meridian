<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\meridian_core\Validation\BundleRulesValidatorBase;
use Drupal\node\NodeInterface;

/**
 * Validates MeridianDailyRunRules (DN-4).
 */
class MeridianDailyRunRulesValidator extends BundleRulesValidatorBase {

  /**
   * {@inheritdoc}
   */
  protected function bundle(): string {
    return 'daily_run';
  }

  /**
   * {@inheritdoc}
   */
  protected function check(NodeInterface $node): void {
    $status = $this->choice($node, 'field_status', ['success', 'failed', 'skipped']);
    if ($status === 'skipped' && $this->isEmpty($node, 'field_skip_reason')) {
      $this->fail('field_skip_reason', 'meridian.daily_run.skip_reason_required', 'A skip reason is required when the run was skipped.');
    }
    if ($status === 'success') {
      if (!$this->isEmpty($node, 'field_skip_reason')) {
        $this->fail('field_skip_reason', 'meridian.daily_run.skip_reason_forbidden', 'A successful run has no skip reason.');
      }
      if ($this->isEmpty($node, 'field_watchlist_source')) {
        $this->fail('field_watchlist_source', 'meridian.daily_run.watchlist_source_required', 'The watchlist source is required when the run succeeded.');
      }
    }
    $decisions = $this->integer($node, 'field_decisions_count');
    $buys = $this->integer($node, 'field_buy_count');
    if ($decisions !== NULL && $buys !== NULL && $decisions >= 0 && $buys >= 0 && $buys > $decisions) {
      $this->fail('field_buy_count', 'meridian.daily_run.buy_count_exceeds_decisions', 'The buy count cannot exceed the decisions count.');
    }
    $started = $this->integer($node, 'field_started_at');
    $finished = $this->integer($node, 'field_finished_at');
    if ($started !== NULL && $finished !== NULL && $finished < $started) {
      $this->fail('field_finished_at', 'meridian.daily_run.finished_before_started', 'The run cannot finish before it started.');
    }
  }

}
