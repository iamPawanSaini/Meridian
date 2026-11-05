<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Validation;

use Drupal\Core\Entity\Plugin\DataType\EntityAdapter;
use Drupal\node\NodeInterface;
use Symfony\Component\Validator\Constraint;
use Symfony\Component\Validator\ConstraintValidator;

/**
 * Base of the cross-field validators, one per Meridian bundle.
 *
 * A validator returns at once for other bundles. A rule that reads another
 * field returns without a violation when that field is missing or invalid,
 * because the field's own rule reports it (one violation per rejection).
 */
abstract class BundleRulesValidatorBase extends ConstraintValidator {

  /**
   * The bundle this validator applies to.
   */
  abstract protected function bundle(): string;

  /**
   * Checks the node. Called for the bundle only.
   */
  abstract protected function check(NodeInterface $node): void;

  /**
   * {@inheritdoc}
   */
  public function validate(mixed $value, Constraint $constraint): void {
    if ($value instanceof EntityAdapter) {
      $value = $value->getValue();
    }
    if (!$value instanceof NodeInterface || $value->bundle() !== $this->bundle()) {
      return;
    }
    $this->check($value);
  }

  /**
   * Returns the main value of a field, or NULL when it is empty.
   */
  protected function value(NodeInterface $node, string $field): mixed {
    if (!$node->hasField($field)) {
      return NULL;
    }
    $item = $node->get($field)->first();
    if ($item === NULL) {
      return NULL;
    }
    $main = $item::mainPropertyName();
    $value = $main === NULL ? NULL : $item->get($main)->getValue();
    return $value === '' ? NULL : $value;
  }

  /**
   * Returns the value of a list field when it is one of the given values.
   *
   * @param \Drupal\node\NodeInterface $node
   *   The node.
   * @param string $field
   *   The field machine name.
   * @param string[] $allowed
   *   The valid values.
   */
  protected function choice(NodeInterface $node, string $field, array $allowed): ?string {
    $value = $this->value($node, $field);
    return (is_string($value) && in_array($value, $allowed, TRUE)) ? $value : NULL;
  }

  /**
   * Returns a symbol field when it matches the symbol pattern.
   */
  protected function symbol(NodeInterface $node, string $field): ?string {
    $value = $this->value($node, $field);
    return Patterns::matches(Patterns::SYMBOL, $value) ? $value : NULL;
  }

  /**
   * Returns a date-only field as Y-m-d, or NULL when empty or not a date.
   */
  protected function date(NodeInterface $node, string $field): ?string {
    $value = $this->value($node, $field);
    return Patterns::matches(Patterns::DATE_ONLY, $value) ? $value : NULL;
  }

  /**
   * Returns a decimal field as a canonical string, or NULL.
   */
  protected function decimal(NodeInterface $node, string $field): ?string {
    return Decimals::normalize($this->value($node, $field));
  }

  /**
   * Returns a decimal field only when it is a number above zero.
   */
  protected function positive(NodeInterface $node, string $field): ?string {
    $number = $this->decimal($node, $field);
    return ($number !== NULL && Decimals::compare($number, '0') === 1) ? $number : NULL;
  }

  /**
   * Returns an integer field, or NULL when empty or not an integer.
   */
  protected function integer(NodeInterface $node, string $field): ?int {
    $value = $this->value($node, $field);
    return (is_int($value) || (is_string($value) && preg_match('/^-?[0-9]+$/D', $value) === 1)) ? (int) $value : NULL;
  }

  /**
   * Returns a boolean field, or NULL when it is not set.
   */
  protected function flag(NodeInterface $node, string $field): ?bool {
    $value = $this->value($node, $field);
    return $value === NULL ? NULL : in_array($value, [1, '1', TRUE], TRUE);
  }

  /**
   * Whether a field has no value.
   */
  protected function isEmpty(NodeInterface $node, string $field): bool {
    return $this->value($node, $field) === NULL;
  }

  /**
   * Adds a violation at a field with a stable code.
   *
   * @param string $field
   *   The field machine name, used as the property path.
   * @param string $code
   *   The meridian.* violation code.
   * @param string $message
   *   The message.
   * @param array<string, mixed> $params
   *   The placeholder values.
   */
  protected function fail(string $field, string $code, string $message, array $params = []): void {
    $this->context->buildViolation($message, $params)
      ->atPath($field)
      ->setCode($code)
      ->addViolation();
  }

}
