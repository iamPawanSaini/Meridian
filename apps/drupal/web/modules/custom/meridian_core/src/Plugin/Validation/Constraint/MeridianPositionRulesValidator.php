<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\Field\EntityReferenceFieldItemListInterface;
use Drupal\meridian_core\Validation\BundleRulesValidatorBase;
use Drupal\meridian_core\Validation\Decimals;
use Drupal\node\NodeInterface;

/**
 * Validates MeridianPositionRules (FR-08, FR-10, DN-4, DN-6).
 */
class MeridianPositionRulesValidator extends BundleRulesValidatorBase {

  /**
   * The fields that exist only on a closed position.
   */
  protected const EXIT_FIELDS = ['field_exit_date', 'field_exit_price', 'field_exit_reason', 'field_realised_pnl'];

  /**
   * {@inheritdoc}
   */
  protected function bundle(): string {
    return 'position';
  }

  /**
   * {@inheritdoc}
   */
  protected function check(NodeInterface $node): void {
    $this->checkPrices($node);
    $this->checkDates($node);
    $this->checkStatusFields($node);
    $this->checkDecision($node);
  }

  /**
   * Stop and target against the entry price.
   */
  protected function checkPrices(NodeInterface $node): void {
    $entry = $this->positive($node, 'field_entry_price');
    if ($entry === NULL) {
      return;
    }
    $stop = $this->positive($node, 'field_stop_price');
    if ($stop !== NULL && Decimals::compare($stop, $entry) !== -1) {
      $this->fail('field_stop_price', 'meridian.position.stop_not_below_entry', 'The stop price must be below the entry price.');
    }
    $target = $this->decimal($node, 'field_target_price');
    if ($target !== NULL && Decimals::compare($target, $entry) !== 1) {
      $this->fail('field_target_price', 'meridian.position.target_not_above_entry', 'The target price must be above the entry price.');
    }
  }

  /**
   * Time stop, exit date and mark date against the entry date.
   */
  protected function checkDates(NodeInterface $node): void {
    $entry = $this->date($node, 'field_entry_date');
    $mode = $this->choice($node, 'field_mode', ['long', 'short']);
    $time_stop_empty = $this->isEmpty($node, 'field_time_stop_date');
    if ($mode === 'short') {
      if ($time_stop_empty) {
        $this->fail('field_time_stop_date', 'meridian.position.time_stop_required', 'A short position needs a time stop date.');
      }
      else {
        $time_stop = $this->date($node, 'field_time_stop_date');
        if ($entry !== NULL && $time_stop !== NULL && $time_stop <= $entry) {
          $this->fail('field_time_stop_date', 'meridian.position.time_stop_not_after_entry', 'The time stop date must be after the entry date.');
        }
      }
    }
    elseif ($mode === 'long' && !$time_stop_empty) {
      $this->fail('field_time_stop_date', 'meridian.position.time_stop_forbidden', 'A long position has no time stop date.');
    }
    $exit = $this->date($node, 'field_exit_date');
    if ($entry !== NULL && $exit !== NULL && $exit <= $entry) {
      $this->fail('field_exit_date', 'meridian.position.exit_not_after_entry', 'The exit date must be after the entry date.');
    }
    $mark = $this->date($node, 'field_last_mark_date');
    if ($entry !== NULL && $mark !== NULL && $mark < $entry) {
      $this->fail('field_last_mark_date', 'meridian.position.mark_before_entry', 'The last mark date cannot be before the entry date.');
    }
  }

  /**
   * Fields that are required or empty by the status (DN-4).
   */
  protected function checkStatusFields(NodeInterface $node): void {
    $status = $this->choice($node, 'field_status', ['open', 'closed']);
    if ($status === 'closed') {
      foreach (self::EXIT_FIELDS as $field) {
        if ($this->isEmpty($node, $field)) {
          $this->fail($field, 'meridian.position.exit_field_required', 'This field is required when the position is closed.');
        }
      }
      if (!$this->isEmpty($node, 'field_unrealised_pnl')) {
        $this->fail('field_unrealised_pnl', 'meridian.position.unrealised_pnl_forbidden', 'A closed position has no unrealised profit or loss.');
      }
    }
    elseif ($status === 'open') {
      foreach (self::EXIT_FIELDS as $field) {
        if (!$this->isEmpty($node, $field)) {
          $this->fail($field, 'meridian.position.exit_field_forbidden', 'This field must be empty while the position is open.');
        }
      }
    }
  }

  /**
   * The opening Decision (DN-6), read through the reference item.
   */
  protected function checkDecision(NodeInterface $node): void {
    $items = $node->hasField('field_decision') ? $node->get('field_decision') : NULL;
    // referencedEntities() also returns an unsaved Decision set on the item.
    $targets = $items instanceof EntityReferenceFieldItemListInterface ? $items->referencedEntities() : [];
    $decision = $targets[0] ?? NULL;
    if (!$decision instanceof NodeInterface || $decision->bundle() !== 'decision') {
      return;
    }
    if ($this->value($decision, 'field_action') !== 'BUY') {
      $this->fail('field_decision', 'meridian.position.decision_not_buy', 'The decision must have the action BUY.');
    }
    $symbol = $this->symbol($node, 'field_symbol');
    $decision_symbol = $this->symbol($decision, 'field_symbol');
    if ($symbol !== NULL && $decision_symbol !== NULL && $symbol !== $decision_symbol) {
      $this->fail('field_decision', 'meridian.position.decision_symbol_mismatch', 'The decision must be for the same symbol.');
    }
    $mode = $this->choice($node, 'field_mode', ['long', 'short']);
    $decision_mode = $this->choice($decision, 'field_mode', ['long', 'short']);
    if ($mode !== NULL && $decision_mode !== NULL && $mode !== $decision_mode) {
      $this->fail('field_decision', 'meridian.position.decision_mode_mismatch', 'The decision must have the same mode.');
    }
    $entry = $this->date($node, 'field_entry_date');
    $decision_date = $this->date($decision, 'field_trade_date');
    if ($entry !== NULL && $decision_date !== NULL && $decision_date > $entry) {
      $this->fail('field_decision', 'meridian.position.decision_after_entry', 'The decision cannot be dated after the entry date.');
    }
  }

}
