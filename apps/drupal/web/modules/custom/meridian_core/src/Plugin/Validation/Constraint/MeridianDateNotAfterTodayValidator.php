<?php

declare(strict_types=1);

namespace Drupal\meridian_core\Plugin\Validation\Constraint;

use Drupal\Component\Datetime\TimeInterface;
use Drupal\Core\DependencyInjection\ContainerInjectionInterface;
use Drupal\meridian_core\Validation\FieldValidatorBase;
use Drupal\meridian_core\Validation\FieldValues;
use Drupal\meridian_core\Validation\Patterns;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\Validator\Constraint;
use Symfony\Component\Validator\Exception\UnexpectedTypeException;

/**
 * Validates MeridianDateNotAfterToday.
 *
 * Today is the calendar date in Asia/Kolkata at the current time of the
 * datetime.time service, so tests can fix the clock. A value that is not a
 * date is left to the core date format rule.
 */
final class MeridianDateNotAfterTodayValidator extends FieldValidatorBase implements ContainerInjectionInterface {

  /**
   * Creates the validator.
   */
  public function __construct(protected TimeInterface $time) {
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container): static {
    return new static($container->get('datetime.time'));
  }

  /**
   * {@inheritdoc}
   */
  public function validate(mixed $value, Constraint $constraint): void {
    if (!$constraint instanceof MeridianDateNotAfterToday) {
      throw new UnexpectedTypeException($constraint, MeridianDateNotAfterToday::class);
    }
    $today = (new \DateTimeImmutable('@' . $this->time->getCurrentTime()))
      ->setTimezone(new \DateTimeZone('Asia/Kolkata'))
      ->format('Y-m-d');
    foreach (FieldValues::of($value) as $delta => $item) {
      if (Patterns::matches(Patterns::DATE_ONLY, $item) && $item > $today) {
        $this->report($value, $delta, $constraint->message, ['@value' => $item], MeridianDateNotAfterToday::CODE);
      }
    }
  }

}
