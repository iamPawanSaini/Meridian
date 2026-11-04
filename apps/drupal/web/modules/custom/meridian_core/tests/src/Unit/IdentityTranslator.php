<?php

declare(strict_types=1);

namespace Drupal\Tests\meridian_core\Unit;

use Symfony\Contracts\Translation\TranslatorInterface;

/**
 * A translator that only replaces placeholders, for unit tests.
 */
class IdentityTranslator implements TranslatorInterface {

  /**
   * {@inheritdoc}
   *
   * @param string $id
   *   The message.
   * @param array<string, mixed> $parameters
   *   The placeholders.
   * @param string|null $domain
   *   Unused.
   * @param string|null $locale
   *   Unused.
   */
  public function trans(string $id, array $parameters = [], ?string $domain = NULL, ?string $locale = NULL): string {
    return strtr($id, $parameters);
  }

  /**
   * {@inheritdoc}
   */
  public function getLocale(): string {
    return 'en';
  }

}
