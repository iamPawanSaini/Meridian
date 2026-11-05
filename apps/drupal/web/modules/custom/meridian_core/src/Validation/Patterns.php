<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Validation;

/**
 * Regular expressions of the Meridian data model (docs/specs/data-model.md).
 *
 * The patterns have no delimiters. Use Patterns::matches(), which anchors them
 * with the D modifier so a trailing newline never passes.
 */
final class Patterns {

  /**
   * An ISO date with a valid month and day range, without delimiters.
   */
  private const DATE = '[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])';

  public const SYMBOL = '^[A-Z0-9&-]{1,20}$';

  public const VERSION_LABEL = '^[0-9]+\.[0-9]+\.[0-9]+$';

  public const MODEL_NAME = '^[a-z0-9][a-z0-9.-]{0,63}$';

  public const RULE_ID = '^[A-Z][A-Z0-9_-]{1,31}$';

  public const UUID = '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

  public const PAYLOAD_HASH = '^[0-9a-f]{64}$';

  public const DATE_ONLY = '^' . self::DATE . '$';

  public const EXTERNAL_ID_DECISION = '^dec-' . self::DATE . '-[A-Z0-9&-]{1,20}-(long|short)$';

  public const EXTERNAL_ID_POSITION = '^pos-[A-Z0-9&-]{1,20}-(long|short)-' . self::DATE . '$';

  public const EXTERNAL_ID_DAILY_RUN = '^run-' . self::DATE . '$';

  public const EXTERNAL_ID_PRICE_SNAPSHOT = '^px-' . self::DATE . '-[A-Z0-9&-]{1,20}$';

  public const EXTERNAL_ID_WATCHLIST_ITEM = '^wl-[A-Z0-9&-]{1,20}$';

  /**
   * The external_id pattern of each bundle.
   */
  public const EXTERNAL_ID_BY_BUNDLE = [
    'decision' => self::EXTERNAL_ID_DECISION,
    'position' => self::EXTERNAL_ID_POSITION,
    'daily_run' => self::EXTERNAL_ID_DAILY_RUN,
    'price_snapshot' => self::EXTERNAL_ID_PRICE_SNAPSHOT,
    'watchlist_item' => self::EXTERNAL_ID_WATCHLIST_ITEM,
  ];

  /**
   * Tests a value against a pattern, anchored at both ends.
   *
   * @param string $pattern
   *   A pattern constant of this class.
   * @param mixed $value
   *   The value. Anything that is not a string never matches.
   */
  public static function matches(string $pattern, mixed $value): bool {
    if (!is_string($value)) {
      return FALSE;
    }
    return preg_match('/' . $pattern . '/D', $value) === 1;
  }

}
