@IsTest
private class UserAccessMonitorUserSelectorTest {
  private static UserAccessMonitorModels.Criteria baseCriteria(
    String searchTerm,
    Set<Id> sessionIds
  ) {
    UserAccessMonitorModels.Criteria criteria = new UserAccessMonitorModels.Criteria();
    criteria.pageSize = 1;
    criteria.searchTerm = searchTerm;
    criteria.userStatus = 'ALL';
    criteria.sessionStatus = 'ALL';
    criteria.loginRecency = 'ANY';
    criteria.sortField = 'DEFAULT';
    criteria.sortDirection = 'asc';
    criteria.activeSessionUserIds = sessionIds;
    return criteria;
  }

  private static List<Id> walkDefaultOrder(
    UserAccessMonitorUserSelector selector,
    UserAccessMonitorModels.Criteria criteria
  ) {
    List<Id> orderedIds = new List<Id>();
    UserAccessMonitorModels.Cursor cursor = null;
    Integer safety = 0;
    do {
      criteria.afterCursor = cursor;
      UserAccessMonitorModels.UserPageResult page = selector.findDefaultOrder(
        criteria
      );
      for (User row : page.records)
        orderedIds.add(row.Id);
      cursor = page.hasNextPage ? page.nextCursor : null;
      safety++;
    } while (cursor != null && safety < 10);
    return orderedIds;
  }

  @IsTest
  static void defaultOrderPaginatesSessionBucketBeforeOtherBucket() {
    User sessionUser = UserAccessMonitorTestDataFactory.buildUser(
      'Zed',
      'SelectorSession',
      true
    );
    User activeUser = UserAccessMonitorTestDataFactory.buildUser(
      'Amy',
      'SelectorActive',
      true
    );
    User inactiveUser = UserAccessMonitorTestDataFactory.buildUser(
      'Bob',
      'SelectorInactive',
      false
    );
    insert new List<User>{ sessionUser, activeUser, inactiveUser };

    UserAccessMonitorUserSelector selector = new UserAccessMonitorUserSelector();
    UserAccessMonitorModels.Criteria criteria = baseCriteria(
      'Selector',
      new Set<Id>{ sessionUser.Id }
    );

    List<Id> orderedIds = walkDefaultOrder(selector, criteria);

    System.assertEquals(3, orderedIds.size());
    System.assertEquals(
      sessionUser.Id,
      orderedIds[0],
      'The active-session bucket must be exhausted before the other bucket begins.'
    );
    System.assertEquals(activeUser.Id, orderedIds[1]);
    System.assertEquals(inactiveUser.Id, orderedIds[2]);
  }

  @IsTest
  static void defaultOrderTieBreaksDeterministicallyById() {
    User first = UserAccessMonitorTestDataFactory.buildUser(
      'Same',
      'SelectorName',
      true
    );
    insert first;
    User second = UserAccessMonitorTestDataFactory.buildUser(
      'Same',
      'SelectorName',
      true
    );
    insert second;

    UserAccessMonitorUserSelector selector = new UserAccessMonitorUserSelector();
    UserAccessMonitorModels.Criteria criteria = baseCriteria(
      'SelectorName',
      new Set<Id>()
    );

    List<Id> orderedIds = walkDefaultOrder(selector, criteria);

    System.assertEquals(2, orderedIds.size());
    System.assertEquals(
      first.Id,
      orderedIds[0],
      'Rows with identical sort keys must tie-break deterministically by Id.'
    );
    System.assertEquals(second.Id, orderedIds[1]);
  }

  @IsTest
  static void explicitSortOrdersNullFieldValuesLast() {
    User withDeptA = UserAccessMonitorTestDataFactory.buildUser(
      'Dept',
      'A',
      true
    );
    withDeptA.Department = 'Alpha';
    User withDeptB = UserAccessMonitorTestDataFactory.buildUser(
      'Dept',
      'B',
      true
    );
    withDeptB.Department = 'Beta';
    User withNoDept = UserAccessMonitorTestDataFactory.buildUser(
      'Dept',
      'C',
      true
    );
    withNoDept.Department = null;
    insert new List<User>{ withDeptA, withDeptB, withNoDept };

    UserAccessMonitorUserSelector selector = new UserAccessMonitorUserSelector();
    UserAccessMonitorModels.Criteria criteria = baseCriteria(
      'Dept',
      new Set<Id>()
    );
    criteria.sortField = 'department';
    criteria.sortDirection = 'asc';

    List<Id> orderedIds = new List<Id>();
    UserAccessMonitorModels.Cursor cursor = null;
    Integer safety = 0;
    do {
      criteria.afterCursor = cursor;
      UserAccessMonitorModels.UserPageResult page = selector.findBySortField(
        criteria
      );
      for (User row : page.records)
        orderedIds.add(row.Id);
      cursor = page.hasNextPage ? page.nextCursor : null;
      safety++;
    } while (cursor != null && safety < 10);

    System.assertEquals(3, orderedIds.size());
    System.assertEquals(withDeptA.Id, orderedIds[0]);
    System.assertEquals(withDeptB.Id, orderedIds[1]);
    System.assertEquals(
      withNoDept.Id,
      orderedIds[2],
      'A blank Department must sort last regardless of direction.'
    );
  }

  @IsTest
  static void aggregateCountsReflectFilteredCriteria() {
    User neverLoggedInActive = UserAccessMonitorTestDataFactory.buildUser(
      'Count',
      'NeverActive',
      true
    );
    User inactiveUser = UserAccessMonitorTestDataFactory.buildUser(
      'Count',
      'Inactive',
      false
    );
    insert new List<User>{ neverLoggedInActive, inactiveUser };

    UserAccessMonitorUserSelector selector = new UserAccessMonitorUserSelector();
    UserAccessMonitorModels.Criteria criteria = baseCriteria(
      'Count',
      new Set<Id>{ neverLoggedInActive.Id }
    );

    System.assertEquals(2, selector.countMatching(criteria));
    System.assertEquals(1, selector.countActive(criteria));
    System.assertEquals(1, selector.countInactive(criteria));
    System.assertEquals(1, selector.countActiveNeverLoggedIn(criteria));
    System.assertEquals(
      1,
      selector.countActiveNoLoginIn90Days(criteria),
      'A user who never logged in must count as having no login in the last 90 days.'
    );
    System.assertEquals(1, selector.countActiveSessions(criteria));
  }

  @IsTest
  static void countActiveSessionsIsZeroWhenNoSessionIdsProvided() {
    UserAccessMonitorUserSelector selector = new UserAccessMonitorUserSelector();
    UserAccessMonitorModels.Criteria criteria = baseCriteria(
      'NoSessionIds',
      new Set<Id>()
    );

    System.assertEquals(0, selector.countActiveSessions(criteria));
  }

  @IsTest
  static void findProfilesAndRolesReturnUntruncatedResultsInThisOrg() {
    UserAccessMonitorUserSelector selector = new UserAccessMonitorUserSelector();

    UserAccessMonitorModels.ProfileOptionsResult profiles = selector.findProfiles();
    UserAccessMonitorModels.RoleOptionsResult roles = selector.findRoles();

    System.assert(
      !profiles.records.isEmpty(),
      'At least one Profile must exist in any org.'
    );
    System.assertEquals(false, profiles.truncated);
    System.assertEquals(false, roles.truncated);
  }

  @IsTest
  static void isSortFieldSupportedAllowlistsOnlyKnownFields() {
    System.assertEquals(
      true,
      UserAccessMonitorUserSelector.isSortFieldSupported('lastName')
    );
    System.assertEquals(
      true,
      UserAccessMonitorUserSelector.isSortFieldSupported('isActive')
    );
    System.assertEquals(
      false,
      UserAccessMonitorUserSelector.isSortFieldSupported('statusText')
    );
    System.assertEquals(
      false,
      UserAccessMonitorUserSelector.isSortFieldSupported(
        'Name, (SELECT Id FROM Contacts)'
      )
    );
  }
}
