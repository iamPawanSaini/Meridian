<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Validation;

/**
 * Exact comparison of decimal numbers held as strings.
 *
 * Prices have up to 18 significant digits, more than a float can hold, so the
 * rules compare strings and never convert to float.
 */
final class Decimals {

  /**
   * Returns the canonical decimal string of a value, or NULL if not a number.
   */
  public static function normalize(mixed $value): ?string {
    if (is_float($value)) {
      $value = rtrim(rtrim(sprintf('%.12F', $value), '0'), '.');
    }
    elseif (is_int($value)) {
      $value = (string) $value;
    }
    if (!is_string($value) || preg_match('/^-?[0-9]+(\.[0-9]+)?$/D', $value) !== 1) {
      return NULL;
    }
    $negative = str_starts_with($value, '-');
    $unsigned = ltrim($value, '-');
    [$int, $frac] = array_pad(explode('.', $unsigned, 2), 2, '');
    $int = ltrim($int, '0');
    $frac = rtrim($frac, '0');
    if ($int === '' && $frac === '') {
      return '0';
    }
    return ($negative ? '-' : '') . ($int === '' ? '0' : $int) . ($frac === '' ? '' : '.' . $frac);
  }

  /**
   * Compares two decimals: -1, 0 or 1. Returns NULL if either is not a number.
   */
  public static function compare(mixed $a, mixed $b): ?int {
    $a = self::normalize($a);
    $b = self::normalize($b);
    if ($a === NULL || $b === NULL) {
      return NULL;
    }
    $negA = str_starts_with($a, '-');
    $negB = str_starts_with($b, '-');
    if ($negA !== $negB) {
      return $negA ? -1 : 1;
    }
    $result = self::compareUnsigned(ltrim($a, '-'), ltrim($b, '-'));
    return $negA ? -$result : $result;
  }

  /**
   * Compares two non-negative canonical decimals.
   */
  private static function compareUnsigned(string $a, string $b): int {
    [$intA, $fracA] = array_pad(explode('.', $a, 2), 2, '');
    [$intB, $fracB] = array_pad(explode('.', $b, 2), 2, '');
    if (strlen($intA) !== strlen($intB)) {
      return strlen($intA) <=> strlen($intB);
    }
    if ($intA !== $intB) {
      return strcmp($intA, $intB) <=> 0;
    }
    $length = max(strlen($fracA), strlen($fracB));
    return strcmp(str_pad($fracA, $length, '0'), str_pad($fracB, $length, '0')) <=> 0;
  }

}
