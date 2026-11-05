<?php

declare(strict_types=1);

namespace Drupal\Tests\meridian_core\Kernel;

use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\RunTestsInSeparateProcesses;

/**
 * The raw violation paths and codes that T10 maps to JSON pointers.
 *
 * Other Kernel tests normalise the path. This one does not, so a change of the
 * raw form (see README.md, "Violation contract (T10)") fails here.
 */
#[Group('meridian_core')]
#[RunTestsInSeparateProcesses]
class ViolationContractTest extends MeridianKernelTestBase {

  /**
   * Returns the raw (path, code) pairs of an entity, sorted.
   *
   * @param string $bundle
   *   The bundle.
   * @param array<string, mixed> $changes
   *   Field values that replace the baseline.
   *
   * @return list<array{0: string, 1: string}>
   *   The pairs.
   */
  protected function rawViolations(string $bundle, array $changes): array {
    $pairs = [];
    foreach ($this->record($bundle, $changes)->validate() as $violation) {
      $pairs[] = [$violation->getPropertyPath(), (string) $violation->getCode()];
    }
    sort($pairs);
    return $pairs;
  }

  /**
   * Raw paths of Meridian rules, a core rule and a reference.
   */
  public function testRawPathsAndCodes(): void {
    $this->assertSame([['field_symbol', 'meridian.pattern']], $this->rawViolations('decision', ['field_symbol' => 'bad']), 'Meridian single-value rule: the field path');
    $this->assertSame([['field_rule_hits.0', 'meridian.pattern']], $this->rawViolations('decision', ['field_rule_hits' => ['bad']]), 'Meridian multi-value rule: the delta');
    $this->assertSame([['field_modes', 'meridian.duplicate_value']], $this->rawViolations('watchlist_item', ['field_modes' => ['long', 'long']]), 'Meridian list-level rule: the field path');
    $this->assertSame([['field_score.0.value', self::TOO_HIGH]], $this->rawViolations('decision', ['field_score' => '100.01']), 'core value rule: item and property');
    $this->assertSame([['field_mode.0', self::NOT_ALLOWED]], $this->rawViolations('decision', ['field_mode' => 'longg']), 'core list rule: the item');
    $this->assertSame([['field_run.0.target_id', '']], $this->rawViolations('decision', ['field_run' => 99999]), 'reference: target_id, empty code');
    $this->assertSame([['field_trade_date.0', ''], ['field_trade_date.0.value', '']], $this->rawViolations('decision', ['field_trade_date' => '2026-13-45']), 'datetime: empty codes');
    $this->assertSame([['field_external_id', 'meridian.external_id_mismatch']], $this->rawViolations('decision', ['field_symbol' => 'TCS']), 'entity rule: the field path');
    $this->assertSame([['title.0.value', self::TOO_LONG]], $this->rawViolations('decision', ['title' => str_repeat('a', 256)]), 'base field');
    $this->assertSame([['field_score', self::REQUIRED]], $this->rawViolations('decision', ['field_score' => NULL]), 'required: the field path');
    $this->assertSame([['field_quantity.0.value', ''], ['field_quantity.0.value', self::NOT_A_NUMBER]], $this->rawViolations('position', ['field_quantity' => 'abc']), 'non-numeric integer: several violations share the path');
    $this->assertSame([['field_quantity.0.value', '']], $this->rawViolations('position', ['field_quantity' => '1.5']), 'non-integer: one empty code');
  }

}
