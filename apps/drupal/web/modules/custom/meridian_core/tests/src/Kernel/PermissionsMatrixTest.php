<?php

declare(strict_types=1);

// phpcs:disable Drupal.Arrays.Array.LongLineDeclaration -- T09: one test case per line

namespace Drupal\Tests\meridian_core\Kernel;

use Drupal\Core\Cache\CacheableDependencyInterface;
use Drupal\Core\Session\AccountInterface;
use Drupal\Core\Session\AnonymousUserSession;
use Drupal\meridian_core\Hook\AccessHooks;
use Drupal\node\Entity\Node;
use Drupal\node\NodeInterface;
use Drupal\user\Entity\Role;
use Drupal\user\Entity\User;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\RunTestsInSeparateProcesses;

/**
 * The permissions matrix of six roles (FR-16, TC-T09-38 to TC-T09-44).
 *
 * The roles are read from config/sync. A cell is a role by permission, a role
 * by bundle by operation, or a role by restricted field.
 */
#[Group('meridian_core')]
#[RunTestsInSeparateProcesses]
class PermissionsMatrixTest extends MeridianKernelTestBase {

  protected const ROLES = ['administrator', 'analyst', 'engine_ingest', 'dashboard_read', 'anonymous', 'authenticated'];

  protected const MERIDIAN = [
    'view meridian records', 'view meridian watchlist', 'view meridian inputs', 'view meridian raw llm output',
    'administer meridian records', 'ingest meridian records', 'export meridian records',
  ];

  /**
   * The exact permissions each role holds in config (administrator by flag).
   */
  protected const GRANTS = [
    'administrator' => [],
    'analyst' => ['access content', 'view meridian records', 'view meridian inputs', 'view meridian watchlist', 'export meridian records'],
    'engine_ingest' => ['access content', 'ingest meridian records', 'view meridian watchlist'],
    'dashboard_read' => ['access content', 'view meridian records', 'view meridian watchlist'],
    'anonymous' => [],
    'authenticated' => [],
  ];

  protected const BUNDLES = ['daily_run', 'decision', 'position', 'price_snapshot', 'watchlist_item'];

  /**
   * Restricted fields by "bundle.field": the permission and the roles.
   */
  protected const FIELDS = [
    'decision.field_raw_llm_output' => ['view meridian raw llm output', ['administrator']],
    'decision.field_inputs_snapshot' => ['view meridian inputs', ['administrator', 'analyst']],
    'daily_run.field_llm_cost_usd' => ['view meridian inputs', ['administrator', 'analyst']],
    'price_snapshot.field_source' => ['view meridian inputs', ['administrator', 'analyst']],
    'watchlist_item.field_notes' => ['view meridian inputs', ['administrator', 'analyst']],
    'decision.field_source_version' => ['administer meridian records', ['administrator']],
    'decision.field_payload_hash' => ['administer meridian records', ['administrator']],
    'position.field_source_version' => ['administer meridian records', ['administrator']],
    'position.field_payload_hash' => ['administer meridian records', ['administrator']],
    'daily_run.field_source_version' => ['administer meridian records', ['administrator']],
    'daily_run.field_payload_hash' => ['administer meridian records', ['administrator']],
    'price_snapshot.field_source_version' => ['administer meridian records', ['administrator']],
    'price_snapshot.field_payload_hash' => ['administer meridian records', ['administrator']],
  ];

  /**
   * Returns an account for a role (a user, or the anonymous session).
   */
  protected function account(string $role): AccountInterface {
    if ($role === 'anonymous') {
      return new AnonymousUserSession();
    }
    static $count = 0;
    $count++;
    $user = User::create(['name' => "user_$role$count", 'status' => 1, 'roles' => $role === 'authenticated' ? [] : [$role]]);
    $user->save();
    return $user;
  }

  /**
   * Saves a published record of a bundle (a bare save) and returns it.
   */
  protected function node(string $bundle, bool $published = TRUE): NodeInterface {
    static $made = [];
    $made[$bundle] = ($made[$bundle] ?? 0) + 1;
    if ($made[$bundle] === 1) {
      // The first node of a bundle is the baseline, which may be a reference.
      $node = $this->savedBaseline($bundle);
      if (!$published) {
        $node->setUnpublished()->save();
      }
      return $node;
    }
    $node = $this->record($bundle);
    // Bare saves do not validate; keep the external ID unique per node.
    $node->set('field_external_id', $node->get('field_external_id')->value . '-' . $made[$bundle]);
    if (!$published) {
      $node->setUnpublished();
    }
    $node->save();
    return $node;
  }

  /**
   * {@inheritdoc}
   */
  protected function setUp(): void {
    parent::setUp();
    // User 1 is special in Drupal; keep it out of the matrix.
    User::create(['name' => 'root', 'status' => 1])->save();
  }

  /**
   * The seven permissions are defined as planned (TC-T09-38).
   */
  public function testPermissionDefinitions(): void {
    $definitions = $this->container->get('user.permissions')->getPermissions();
    $own = array_keys(array_filter($definitions, static fn (array $p): bool => $p['provider'] === 'meridian_core'));
    sort($own);
    $expected = self::MERIDIAN;
    sort($expected);
    $this->assertSame($expected, $own, 'exactly the seven permissions');
    $restricted = array_keys(array_filter($definitions, static fn (array $p): bool => $p['provider'] === 'meridian_core' && !empty($p['restrict access'])));
    sort($restricted);
    $this->assertSame(['administer meridian records', 'view meridian raw llm output'], $restricted);
  }

  /**
   * Role config has exact permission sets, no extras (TC-T09-39).
   */
  public function testRoleConfiguration(): void {
    $weights = [];
    foreach (self::ROLES as $id) {
      $role = Role::load($id) ?? $this->fail("Role $id is missing.");
      if ($id === 'administrator') {
        $this->assertTrue($role->isAdmin(), 'administrator is_admin');
      }
      else {
        $this->assertFalse($role->isAdmin(), "$id is not admin");
        $granted = $role->getPermissions();
        sort($granted);
        $expected = self::GRANTS[$id];
        sort($expected);
        $this->assertSame($expected, $granted, "$id has exactly its permissions");
      }
      $weights[] = $role->getWeight();
    }
    $this->assertSame($weights, array_values(array_unique($weights)), 'role weights are distinct');
  }

  /**
   * Role by permission: 6 roles by 9 permissions = 54 cells (TC-T09-40).
   */
  public function testRoleByPermissionCells(): void {
    $permissions = array_merge(self::MERIDIAN, ['access content', 'bypass node access']);
    $cells = 0;
    foreach (self::ROLES as $role) {
      $account = $this->account($role);
      foreach ($permissions as $permission) {
        $expected = $role === 'administrator' || in_array($permission, self::GRANTS[$role], TRUE);
        $this->assertSame($expected, $account->hasPermission($permission), "$role / $permission");
        $cells++;
      }
    }
    $this->assertSame(54, $cells);
  }

  /**
   * Role by bundle by operation: 6 x 5 x 4 = 120 cells (TC-T09-41).
   */
  public function testRoleByBundleByOperationCells(): void {
    $handler = $this->container->get('entity_type.manager')->getAccessControlHandler('node');
    $nodes = [];
    foreach (self::BUNDLES as $bundle) {
      $nodes[$bundle] = $this->node($bundle);
    }
    $cells = 0;
    foreach (self::ROLES as $role) {
      $account = $this->account($role);
      foreach (self::BUNDLES as $bundle) {
        $view_permission = $bundle === 'watchlist_item' ? 'view meridian watchlist' : 'view meridian records';
        $can_view = $role === 'administrator' || in_array($view_permission, self::GRANTS[$role], TRUE);
        $this->assertSame($can_view, $nodes[$bundle]->access('view', $account), "$role view $bundle");
        $this->assertSame($role === 'administrator', $nodes[$bundle]->access('update', $account), "$role update $bundle");
        $this->assertSame($role === 'administrator', $nodes[$bundle]->access('delete', $account), "$role delete $bundle");
        $this->assertSame($role === 'administrator', $handler->createAccess($bundle, $account), "$role create $bundle");
        $cells += 4;
      }
    }
    $this->assertSame(120, $cells);
  }

  /**
   * Unpublished records stay hidden and the hooks never allow (TC-T09-42).
   */
  public function testUnpublishedRecordsAndNeutralRule(): void {
    foreach (self::BUNDLES as $bundle) {
      $node = $this->node($bundle, FALSE);
      foreach (['analyst', 'dashboard_read', 'engine_ingest'] as $role) {
        $this->assertFalse($node->access('view', $this->account($role)), "$role must not see an unpublished $bundle");
      }
      $this->assertTrue($node->access('view', $this->account('administrator')), "administrator sees an unpublished $bundle");
    }
    $hooks = new AccessHooks();
    $node = $this->node('decision');
    foreach (self::ROLES as $role) {
      $account = $this->account($role);
      foreach (['view', 'update', 'delete'] as $operation) {
        $result = $hooks->nodeAccess($node, $operation, $account);
        $this->assertFalse($result->isAllowed(), "$role $operation: the hook never allows");
        $this->assertTrue($result->isNeutral() || $result->isForbidden());
      }
      $this->assertFalse($hooks->nodeCreateAccess($account, [], 'decision')->isAllowed());
      $this->assertFalse($hooks->fieldAccess('view', $node->get('field_raw_llm_output')->getFieldDefinition(), $account)->isAllowed());
    }
    // An unrelated role with only access content does not see Meridian nodes.
    Role::create(['id' => 'content_only', 'label' => 'Content only'])->grantPermission('access content')->save();
    $user = User::create(['name' => 'content_only', 'status' => 1, 'roles' => ['content_only']]);
    $user->save();
    foreach (self::BUNDLES as $bundle) {
      $this->assertFalse($this->node($bundle)->access('view', $user), "access content only: $bundle");
    }
    // Other bundles are not touched by the hooks.
    $this->assertTrue($hooks->nodeAccess(Node::create(['type' => 'other', 'title' => 'x']), 'view', $user)->isNeutral());
  }

  /**
   * Field view access for the restricted fields (TC-T09-43).
   */
  public function testRestrictedFieldCells(): void {
    $cells = 0;
    $nodes = [];
    foreach (self::BUNDLES as $bundle) {
      $nodes[$bundle] = $this->node($bundle);
    }
    foreach (self::FIELDS as $key => [$permission, $roles]) {
      [$bundle, $field] = explode('.', $key);
      foreach (self::ROLES as $role) {
        $account = $this->account($role);
        $this->assertSame(in_array($role, $roles, TRUE), $nodes[$bundle]->get($field)->access('view', $account), "$role views $key");
        $cells++;
      }
    }
    $this->assertSame(78, $cells);
    // An unrestricted field is viewable by a read role, and field edit is not
    // restricted by this module.
    $dashboard = $this->account('dashboard_read');
    $this->assertTrue($nodes['decision']->get('field_score')->access('view', $dashboard));
    $hooks = new AccessHooks();
    $definition = $nodes['decision']->get('field_raw_llm_output')->getFieldDefinition();
    $this->assertTrue($hooks->fieldAccess('edit', $definition, $dashboard)->isNeutral(), 'edit is not restricted');
  }

  /**
   * Access results carry the permissions cache context (TC-T09-44).
   */
  public function testCacheContexts(): void {
    $node = $this->node('decision');
    $account = $this->account('analyst');
    foreach (['view', 'update', 'delete'] as $operation) {
      $result = $node->access($operation, $account, TRUE);
      $this->assertInstanceOf(CacheableDependencyInterface::class, $result);
      $this->assertContains('user.permissions', $result->getCacheContexts(), $operation);
    }
    $create = $this->container->get('entity_type.manager')->getAccessControlHandler('node')->createAccess('decision', $account, [], TRUE);
    $this->assertInstanceOf(CacheableDependencyInterface::class, $create);
    $this->assertContains('user.permissions', $create->getCacheContexts(), 'create');
    $field = $node->get('field_inputs_snapshot')->access('view', $account, TRUE);
    $this->assertInstanceOf(CacheableDependencyInterface::class, $field);
    $this->assertContains('user.permissions', $field->getCacheContexts(), 'field view');
  }

}
