<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Core\DependencyInjection\ContainerInjectionInterface;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\Core\Entity\Plugin\DataType\EntityAdapter;
use Drupal\meridian_core\Validation\BundleRulesValidatorBase;
use Drupal\meridian_core\Validation\Patterns;
use Drupal\node\NodeInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\Validator\Constraint;
use Symfony\Component\Validator\Exception\UnexpectedTypeException;

/**
 * Validates MeridianExternalIdMatches (DN-5).
 *
 * The external ID must equal the D3 format built from the record's own natural
 * key fields. The rule adds nothing when the external ID or a key field is
 * missing or invalid, because the rule of that field reports it.
 */
final class MeridianExternalIdMatchesValidator extends BundleRulesValidatorBase implements ContainerInjectionInterface {

  /**
   * The bundle being validated.
   */
  protected string $currentBundle = '';

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
    return $this->currentBundle;
  }

  /**
   * {@inheritdoc}
   */
  public function validate(mixed $value, Constraint $constraint): void {
    if (!$constraint instanceof MeridianExternalIdMatches) {
      throw new UnexpectedTypeException($constraint, MeridianExternalIdMatches::class);
    }
    if ($value instanceof EntityAdapter) {
      $value = $value->getValue();
    }
    if (!$value instanceof NodeInterface || !isset(Patterns::EXTERNAL_ID_BY_BUNDLE[$value->bundle()])) {
      return;
    }
    $this->currentBundle = $value->bundle();
    $this->check($value);
  }

  /**
   * {@inheritdoc}
   */
  protected function check(NodeInterface $node): void {
    $actual = $this->value($node, 'field_external_id');
    if (!Patterns::matches(Patterns::EXTERNAL_ID_BY_BUNDLE[$this->currentBundle], $actual)) {
      return;
    }
    $expected = $this->expected($node);
    if ($expected === NULL || $expected === $actual || $this->reportedAsImmutable($node, $actual)) {
      return;
    }
    $this->fail('field_external_id', MeridianExternalIdMatches::CODE, 'The external ID must be @expected.', ['@expected' => $expected]);
  }

  /**
   * Whether the immutable rule already reports the difference.
   *
   * A saved record whose external ID (or, for a Watchlist Item, symbol) was
   * changed is reported by MeridianImmutable, so one change gives one
   * violation. A changed natural-key field with the old external ID is still
   * reported here.
   */
  protected function reportedAsImmutable(NodeInterface $node, string $actual): bool {
    if ($node->isNew()) {
      return FALSE;
    }
    $stored = $this->entityTypeManager->getStorage('node')->loadUnchanged($node->id());
    if ($stored === NULL) {
      return FALSE;
    }
    if ($stored->get('field_external_id')->value !== $actual) {
      return TRUE;
    }
    return $this->currentBundle === 'watchlist_item' && $stored->get('field_symbol')->value !== $node->get('field_symbol')->value;
  }

  /**
   * Builds the external ID from the key fields, or NULL if one is unusable.
   */
  protected function expected(NodeInterface $node): ?string {
    $symbol = $this->symbol($node, 'field_symbol');
    $mode = $this->choice($node, 'field_mode', ['long', 'short']);
    switch ($this->currentBundle) {
      case 'decision':
        $date = $this->date($node, 'field_trade_date');
        return ($date && $symbol && $mode) ? "dec-$date-$symbol-$mode" : NULL;

      case 'position':
        $date = $this->date($node, 'field_entry_date');
        return ($date && $symbol && $mode) ? "pos-$symbol-$mode-$date" : NULL;

      case 'daily_run':
        $date = $this->date($node, 'field_trade_date');
        return $date ? "run-$date" : NULL;

      case 'price_snapshot':
        $date = $this->date($node, 'field_trade_date');
        return ($date && $symbol) ? "px-$date-$symbol" : NULL;

      case 'watchlist_item':
        return $symbol ? "wl-$symbol" : NULL;
    }
    return NULL;
  }

}
