<?php

declare(strict_types=1);

namespace Drupal\Tests\meridian_core\Unit;

use Drupal\meridian_core\Plugin\Validation\Constraint\MeridianJsonDocument;
use Drupal\meridian_core\Plugin\Validation\Constraint\MeridianJsonDocumentValidator;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\TestCase;

/**
 * The JSON document rule: valid JSON object, size in bytes (DN-7, TC-T09-09).
 */
#[Group('meridian_core')]
class JsonDocumentValidatorTest extends TestCase {

  use ValidatorHarnessTrait;

  /**
   * A JSON object of exactly the given size in bytes.
   */
  protected function json(int $bytes, string $filler = 'a'): string {
    $fill = $bytes - strlen('{"k":""}');
    return '{"k":"' . str_repeat($filler, intdiv($fill, strlen($filler))) . str_repeat('a', $fill % strlen($filler)) . '"}';
  }

  /**
   * Runs the validator.
   *
   * @return string[]
   *   The violation codes.
   */
  protected function check(mixed $value, bool $objectOnly = TRUE, int $maxBytes = 100): array {
    return $this->codes(new MeridianJsonDocumentValidator(), $value, new MeridianJsonDocument(objectOnly: $objectOnly, maxBytes: $maxBytes));
  }

  /**
   * Invalid JSON and JSON that is not an object are rejected.
   */
  public function testRejectsInvalidAndNonObjects(): void {
    foreach (['{', 'not json', "{'a':1}", '{"a":1,}'] as $value) {
      $this->assertSame([MeridianJsonDocument::CODE_INVALID], $this->check($value), $value);
    }
    foreach (['[]', '[1]', '"text"', '5', 'null', 'true'] as $value) {
      $this->assertSame([MeridianJsonDocument::CODE_NOT_OBJECT], $this->check($value), $value);
    }
    $this->assertSame([MeridianJsonDocument::CODE_INVALID], $this->check(['a' => 1]), 'a PHP array is not a stored string');
  }

  /**
   * Objects are accepted, and any JSON when objects are not required.
   */
  public function testAcceptsObjects(): void {
    foreach (['{}', '{"a":1}', '{"status":"not_called"}', '{"a":{"b":[1,2]}}'] as $value) {
      $this->assertSame([], $this->check($value), $value);
    }
    $this->assertSame([], $this->check('[1]', FALSE));
  }

  /**
   * Empty values are left to the required rule, so there is no second error.
   */
  public function testEmptyValuesAddNothing(): void {
    $this->assertSame([], $this->check(''));
    $this->assertSame([], $this->check(NULL));
  }

  /**
   * The limit is in bytes, at the limit and one byte over.
   */
  public function testByteLimit(): void {
    $this->assertSame([], $this->check($this->json(100), TRUE, 100));
    $this->assertSame([MeridianJsonDocument::CODE_TOO_LARGE], $this->check($this->json(101), TRUE, 100));
    // Three-byte characters: the character count is below the byte count.
    $euro = '€';
    $at_limit = $this->json(100, $euro);
    $this->assertSame(100, strlen($at_limit));
    $this->assertLessThan(100, mb_strlen($at_limit));
    $this->assertSame([], $this->check($at_limit, TRUE, 100));
    $this->assertSame([MeridianJsonDocument::CODE_TOO_LARGE], $this->check($this->json(101, $euro), TRUE, 100));
    // The two limits of the Decision.
    $this->assertSame([], $this->check($this->json(65536), TRUE, 65536));
    $this->assertSame([MeridianJsonDocument::CODE_TOO_LARGE], $this->check($this->json(65537), TRUE, 65536));
    $this->assertSame([], $this->check($this->json(32768), TRUE, 32768));
    $this->assertSame([MeridianJsonDocument::CODE_TOO_LARGE], $this->check($this->json(32769), TRUE, 32768));
  }

}
