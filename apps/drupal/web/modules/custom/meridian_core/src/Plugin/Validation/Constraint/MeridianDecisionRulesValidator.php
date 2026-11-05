<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\meridian_core\Validation\BundleRulesValidatorBase;
use Drupal\node\NodeInterface;

/**
 * Validates MeridianDecisionRules (FR-05, FR-06).
 */
class MeridianDecisionRulesValidator extends BundleRulesValidatorBase {

  /**
   * {@inheritdoc}
   */
  protected function bundle(): string {
    return 'decision';
  }

  /**
   * {@inheritdoc}
   */
  protected function check(NodeInterface $node): void {
    $actions = ['BUY', 'AVOID'];
    $pre = $this->choice($node, 'field_pre_llm_action', $actions);
    $action = $this->choice($node, 'field_action', $actions);
    $vetoed = $this->flag($node, 'field_vetoed');

    if ($action === 'BUY') {
      if ($pre !== NULL && $pre !== 'BUY') {
        $this->fail('field_action', 'meridian.decision.buy_requires_pre_buy', 'The action can be BUY only when the action before the LLM review is BUY.');
      }
      elseif ($vetoed === TRUE) {
        $this->fail('field_action', 'meridian.decision.buy_vetoed', 'The action cannot be BUY when the decision is vetoed.');
      }
    }
    if ($vetoed === TRUE && $pre !== NULL && $pre !== 'BUY') {
      $this->fail('field_vetoed', 'meridian.decision.veto_requires_pre_buy', 'A decision can be vetoed only when the action before the LLM review is BUY.');
    }
    if ($vetoed === TRUE && $this->isEmpty($node, 'field_veto_reason')) {
      $this->fail('field_veto_reason', 'meridian.decision.veto_reason_required', 'A veto reason is required when the decision is vetoed.');
    }
    if ($vetoed === FALSE && !$this->isEmpty($node, 'field_veto_reason')) {
      $this->fail('field_veto_reason', 'meridian.decision.veto_reason_forbidden', 'A veto reason is allowed only when the decision is vetoed.');
    }
  }

}
