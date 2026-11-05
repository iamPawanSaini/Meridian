<?php

declare(strict_types=1);

namespace Drupal\Tests\meridian_core\Traits;

use Drupal\node\Entity\Node;
use Drupal\node\NodeInterface;

/**
 * Builds one valid baseline record per bundle (0 violations).
 *
 * Each rejection case changes exactly one thing with withValue() or the
 * $values argument, so it yields exactly one violation. A value of NULL
 * removes the field value.
 */
trait MeridianRecordFactoryTrait {

  /**
   * The saved Daily Run that records refer to.
   */
  protected ?NodeInterface $referenceRun = NULL;

  /**
   * The saved BUY Decision that Positions refer to.
   */
  protected ?NodeInterface $referenceDecision = NULL;

  /**
   * A 64-character lowercase hex payload hash.
   */
  protected function hash(string $seed = 'a'): string {
    return hash('sha256', $seed);
  }

  /**
   * Returns the baseline field values of a bundle (without references).
   *
   * @return array<string, mixed>
   *   Field values by machine name. The title is the key 'title'.
   */
  protected function baselineValues(string $bundle): array {
    return match ($bundle) {
      'decision' => [
        'title' => 'RELIANCE long 2026-11-03',
        'field_external_id' => 'dec-2026-11-03-RELIANCE-long',
        'field_trade_date' => '2026-11-03',
        'field_symbol' => 'RELIANCE',
        'field_mode' => 'long',
        'field_score' => '72.50',
        'field_pre_llm_action' => 'BUY',
        'field_action' => 'BUY',
        'field_vetoed' => 0,
        'field_rule_hits' => ['TREND_OK', 'VOL_OK'],
        'field_rule_version' => '1.0.0',
        'field_prompt_version' => '1.0.0',
        'field_model_name' => 'claude-sonnet-5-5',
        'field_inputs_snapshot' => '{"close":2850.5}',
        'field_raw_llm_output' => '{"status":"not_called"}',
        'field_close_price' => '2850.5000',
        'field_source_version' => 1,
        'field_payload_hash' => $this->hash('decision'),
      ],
      'position' => [
        'title' => 'RELIANCE long 2026-11-03',
        'field_external_id' => 'pos-RELIANCE-long-2026-11-03',
        'field_symbol' => 'RELIANCE',
        'field_mode' => 'long',
        'field_status' => 'open',
        'field_entry_date' => '2026-11-03',
        'field_entry_price' => '2850.5000',
        'field_quantity' => 10,
        'field_stop_price' => '2800.0000',
        'field_target_price' => '2950.0000',
        'field_costs_total' => '12.34',
        'field_source_version' => 1,
        'field_payload_hash' => $this->hash('position'),
      ],
      'daily_run' => [
        'title' => 'Run 2026-11-03',
        'field_external_id' => 'run-2026-11-03',
        'field_trade_date' => '2026-11-03',
        'field_run_id' => '123e4567-e89b-42d3-a456-426614174000',
        'field_attempt' => 1,
        'field_status' => 'success',
        'field_watchlist_source' => 'drupal',
        'field_symbols_total' => 2,
        'field_decisions_count' => 2,
        'field_buy_count' => 1,
        'field_veto_count' => 0,
        'field_failure_count' => 0,
        'field_llm_cost_usd' => '0.1234',
        'field_rule_version' => '1.0.0',
        'field_prompt_version' => '1.0.0',
        'field_model_name' => 'claude-sonnet-5-5',
        'field_started_at' => 1793700000,
        'field_finished_at' => 1793700060,
        'field_source_version' => 1,
        'field_payload_hash' => $this->hash('run'),
      ],
      'price_snapshot' => [
        'title' => 'RELIANCE 2026-11-03',
        'field_external_id' => 'px-2026-11-03-RELIANCE',
        'field_trade_date' => '2026-11-03',
        'field_symbol' => 'RELIANCE',
        'field_open' => '100.0000',
        'field_high' => '110.0000',
        'field_low' => '95.0000',
        'field_close' => '105.0000',
        'field_volume' => 1000,
        'field_adjusted' => 0,
        'field_source' => 'yfinance',
        'field_source_version' => 1,
        'field_payload_hash' => $this->hash('price'),
      ],
      'watchlist_item' => [
        'title' => 'Reliance Industries',
        'field_external_id' => 'wl-RELIANCE',
        'field_symbol' => 'RELIANCE',
        'field_enabled' => 1,
        'field_modes' => ['long'],
        'field_sort_order' => 1,
      ],
      default => throw new \InvalidArgumentException("Unknown bundle $bundle"),
    };
  }

  /**
   * Creates an unsaved baseline record with the given changes.
   *
   * @param string $bundle
   *   The bundle.
   * @param array<string, mixed> $values
   *   Field values that replace the baseline. NULL removes a value.
   */
  protected function record(string $bundle, array $values = []): NodeInterface {
    $values = $values + $this->baselineValues($bundle);
    if ($bundle === 'decision' && !array_key_exists('field_run', $values)) {
      $values['field_run'] = $this->referenceRun()->id();
    }
    if ($bundle === 'position') {
      if (!array_key_exists('field_run', $values)) {
        $values['field_run'] = $this->referenceRun()->id();
      }
      if (!array_key_exists('field_decision', $values)) {
        $values['field_decision'] = $this->referenceDecision()->id();
      }
    }
    return Node::create(['type' => $bundle] + $values);
  }

  /**
   * Returns the saved reference Daily Run (a bare save, no validation).
   */
  protected function referenceRun(): NodeInterface {
    if ($this->referenceRun === NULL) {
      $this->referenceRun = $this->savedBaseline('daily_run');
    }
    return $this->referenceRun;
  }

  /**
   * Returns the saved reference Decision (BUY, RELIANCE, long, 2026-11-03).
   */
  protected function referenceDecision(): NodeInterface {
    if ($this->referenceDecision === NULL) {
      $this->referenceDecision = $this->savedBaseline('decision');
    }
    return $this->referenceDecision;
  }

  /**
   * Returns the saved baseline of a bundle, saving it when it is not stored.
   *
   * A test may have saved the baseline already; the unique key allows one.
   */
  protected function savedBaseline(string $bundle): NodeInterface {
    $external_id = $this->baselineValues($bundle)['field_external_id'];
    $ids = \Drupal::entityTypeManager()->getStorage('node')->getQuery()
      ->accessCheck(FALSE)
      ->condition('type', $bundle)
      ->condition('field_external_id.value', $external_id)
      ->execute();
    if ($ids) {
      return Node::load((int) reset($ids));
    }
    $node = $this->record($bundle);
    $node->save();
    return $node;
  }

}
