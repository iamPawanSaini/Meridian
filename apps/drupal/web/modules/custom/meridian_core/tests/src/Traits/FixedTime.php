<?php

declare(strict_types=1);

namespace Drupal\Tests\meridian_core\Traits;

use Drupal\Component\Datetime\TimeInterface;

/**
 * A clock with a fixed instant, registered over datetime.time in tests.
 */
class FixedTime implements TimeInterface {

  /**
   * The current instant as a Unix timestamp (default 2026-11-04 12:00 UTC).
   */
  public static int $now = 1793793600;

  /**
   * {@inheritdoc}
   */
  public function getRequestTime(): int {
    return self::$now;
  }

  /**
   * {@inheritdoc}
   */
  public function getRequestMicroTime(): float {
    return (float) self::$now;
  }

  /**
   * {@inheritdoc}
   */
  public function getCurrentTime(): int {
    return self::$now;
  }

  /**
   * {@inheritdoc}
   */
  public function getCurrentMicroTime(): float {
    return (float) self::$now;
  }

}
