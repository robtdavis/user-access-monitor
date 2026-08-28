@IsTest
private class UserAccessMonitorControllerTest {
  private static void useFakes(Set<Id> activeSessionUserIds) {
    UserAccessMonitorController.permissionChecker = new UserAccessMonitorTestDataFactory.FakePermissionChecker(
      true
    );
    UserAccessMonitorController.sessionProvider = new UserAccessMonitorTestDataFactory.FakeSessionProvider(
      activeSessionUserIds
    );
  }

  @IsTest
  static void authorizedAccessWithRealPermissionSetGrantsData() {
    User adminUser = UserAccessMonitorTestDataFactory.buildUser(
      'Grace',
      'Hopper',
      true
    );
    insert adminUser;
    PermissionSet permSet = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'User_Access_Monitor_Admin'
      LIMIT 1
    ];
    insert new PermissionSetAssignment(
      AssigneeId = adminUser.Id,
      PermissionSetId = permSet.Id
    );
    UserAccessMonitorController.sessionProvider = new UserAccessMonitorTestDataFactory.FakeSessionProvider(
      new Set<Id>()
    );

    UserAccessMonitorResponse response;
    Test.startTest();
    System.runAs(adminUser) {
      response = UserAccessMonitorController.getUsers(
        new UserAccessMonitorRequest()
      );
    }
    Test.stopTest();

    System.assertNotEquals(
      null,
      response,
      'A genuinely authorized admin must receive a response.'
    );
    System.assert(
      response.totalMatchingUsers >= 1,
      'The admin user itself should be visible in the results.'
    );
  }

  @IsTest
  static void unauthorizedAccessWithoutPermissionSetIsRejected() {
    User plainUser = UserAccessMonitorTestDataFactory.buildUser(
      'No',
      'Access',
      true
    );
    insert plainUser;

    Boolean threwAuthorizationError = false;
    Test.startTest();
    System.runAs(plainUser) {
      try {
        UserAccessMonitorController.getFilterOptions();
      } catch (AuraHandledException authorizationError) {
        threwAuthorizationError = true;
        System.assert(
          authorizationError.getMessage().contains('not authorized'),
          'The message must be safe and specific.'
        );
      }
    }
    Test.stopTest();
    System.assert(
      threwAuthorizationError,
      'A user without the Custom Permission must be rejected with no data returned.'
    );
  }

  @IsTest
  static void combinedFirstAndLastNameSearchMatchesBothFields() {
    User activeUser = UserAccessMonitorTestDataFactory.buildUser(
      'Monitor',
      'TestActive',
      true
    );
    User otherUser = UserAccessMonitorTestDataFactory.buildUser(
      'Someone',
      'Else',
      true
    );
    insert new List<User>{ activeUser, otherUser };
    useFakes(new Set<Id>{ activeUser.Id });

    UserAccessMonitorRequest request = new UserAccessMonitorRequest();
    request.searchTerm = 'Monitor TestActive';

    UserAccessMonitorResponse response = UserAccessMonitorController.getUsers(
      request
    );

    System.assertEquals(
      1,
      response.totalMatchingUsers,
      'A full-name search must match on first and last name together.'
    );
    System.assertEquals(activeUser.Id, response.rows[0].id);
    System.assertEquals(true, response.rows[0].activeSessionDetected);
    System.assertEquals(0, response.rows[0].directPermissionSetCount);
  }

  @IsTest
  static void usernameAndEmailSearchMatch() {
    User targetUser = UserAccessMonitorTestDataFactory.buildUser(
      'Ada',
      'Lovelace',
      true
    );
    User otherUser = UserAccessMonitorTestDataFactory.buildUser(
      'Grace',
      'Hopper',
      true
    );
    insert new List<User>{ targetUser, otherUser };
    useFakes(new Set<Id>());

    UserAccessMonitorRequest usernameRequest = new UserAccessMonitorRequest();
    usernameRequest.searchTerm = targetUser.Username.substringBefore('@');
    UserAccessMonitorResponse usernameResponse = UserAccessMonitorController.getUsers(
      usernameRequest
    );
    System.assertEquals(
      1,
      usernameResponse.totalMatchingUsers,
      'Username search must match the intended user only.'
    );

    UserAccessMonitorRequest emailRequest = new UserAccessMonitorRequest();
    emailRequest.searchTerm = targetUser.Email;
    UserAccessMonitorResponse emailResponse = UserAccessMonitorController.getUsers(
      emailRequest
    );
    System.assertEquals(
      1,
      emailResponse.totalMatchingUsers,
      'Email search must match the intended user only.'
    );
  }

  @IsTest
  static void searchWithWildcardAndQuoteCharactersIsTreatedLiterally() {
    User targetUser = UserAccessMonitorTestDataFactory.buildUser(
      'Ada',
      'Lovelace',
      true
    );
    insert targetUser;
    useFakes(new Set<Id>());

    UserAccessMonitorRequest request = new UserAccessMonitorRequest();
    request.searchTerm = '%_\' OR 1=1 --';

    UserAccessMonitorResponse response = UserAccessMonitorController.getUsers(
      request
    );

    System.assertEquals(
      0,
      response.totalMatchingUsers,
      'Wildcard and quote characters must be treated as literal search text, never as SOQL.'
    );
  }

  @IsTest
  static void userStatusFilterReturnsOnlyMatchingUsers() {
    User activeUser = UserAccessMonitorTestDataFactory.buildUser(
      'Active',
      'Person',
      true
    );
    User inactiveUser = UserAccessMonitorTestDataFactory.buildUser(
      'Inactive',
      'Person',
      false
    );
    insert new List<User>{ activeUser, inactiveUser };
    useFakes(new Set<Id>());

    UserAccessMonitorRequest activeRequest = new UserAccessMonitorRequest();
    activeRequest.searchTerm = 'Person';
    activeRequest.userStatus = 'ACTIVE';
    UserAccessMonitorResponse activeResponse = UserAccessMonitorController.getUsers(
      activeRequest
    );
    System.assertEquals(1, activeResponse.totalMatchingUsers);
    System.assertEquals(true, activeResponse.rows[0].isActive);

    UserAccessMonitorRequest inactiveRequest = new UserAccessMonitorRequest();
    inactiveRequest.searchTerm = 'Person';
    inactiveRequest.userStatus = 'INACTIVE';
    UserAccessMonitorResponse inactiveResponse = UserAccessMonitorController.getUsers(
      inactiveRequest
    );
    System.assertEquals(1, inactiveResponse.totalMatchingUsers);
    System.assertEquals(false, inactiveResponse.rows[0].isActive);
  }

  @IsTest
  static void profileAndRoleFiltersReturnOnlyMatchingUsers() {
    String uniqueSuffix = String.valueOf(Math.abs(Crypto.getRandomInteger()));
    UserRole role = new UserRole(
      DeveloperName = 'UAM_Test_Role_' + uniqueSuffix,
      Name = 'UAM Test Role ' + uniqueSuffix
    );
    insert role;
    User userWithRole = UserAccessMonitorTestDataFactory.buildUser(
      'Has',
      'Role',
      true
    );
    userWithRole.UserRoleId = role.Id;
    User userWithoutRole = UserAccessMonitorTestDataFactory.buildUser(
      'No',
      'Role',
      true
    );
    insert new List<User>{ userWithRole, userWithoutRole };
    useFakes(new Set<Id>());

    UserAccessMonitorRequest profileRequest = new UserAccessMonitorRequest();
    profileRequest.profileId = UserAccessMonitorTestDataFactory.standardProfileId();
    profileRequest.searchTerm = 'Role';
    UserAccessMonitorResponse profileResponse = UserAccessMonitorController.getUsers(
      profileRequest
    );
    System.assertEquals(
      2,
      profileResponse.totalMatchingUsers,
      'Profile filter must include both matching users.'
    );

    UserAccessMonitorRequest roleRequest = new UserAccessMonitorRequest();
    roleRequest.roleId = role.Id;
    roleRequest.searchTerm = 'Role';
    UserAccessMonitorResponse roleResponse = UserAccessMonitorController.getUsers(
      roleRequest
    );
    System.assertEquals(1, roleResponse.totalMatchingUsers);
    System.assertEquals(userWithRole.Id, roleResponse.rows[0].id);

    UserAccessMonitorRequest noRoleRequest = new UserAccessMonitorRequest();
    noRoleRequest.roleId = 'NONE';
    noRoleRequest.searchTerm = 'Role';
    UserAccessMonitorResponse noRoleResponse = UserAccessMonitorController.getUsers(
      noRoleRequest
    );
    System.assertEquals(1, noRoleResponse.totalMatchingUsers);
    System.assertEquals(userWithoutRole.Id, noRoleResponse.rows[0].id);
  }

  @IsTest
  static void loginRecencyFiltersReturnExpectedUsers() {
    User neverLoggedIn = UserAccessMonitorTestDataFactory.buildUser(
      'Never',
      'LoggedIn',
      true
    );
    insert neverLoggedIn;
    useFakes(new Set<Id>());

    UserAccessMonitorRequest neverRequest = new UserAccessMonitorRequest();
    neverRequest.searchTerm = 'LoggedIn';
    neverRequest.loginRecency = 'NEVER';
    System.assertEquals(
      1,
      UserAccessMonitorController.getUsers(neverRequest).totalMatchingUsers
    );

    UserAccessMonitorRequest recentRequest = new UserAccessMonitorRequest();
    recentRequest.searchTerm = 'LoggedIn';
    recentRequest.loginRecency = 'DAYS_7';
    System.assertEquals(
      0,
      UserAccessMonitorController.getUsers(recentRequest).totalMatchingUsers,
      'A user who never logged in must not match a recent-login filter.'
    );

    UserAccessMonitorRequest anyRequest = new UserAccessMonitorRequest();
    anyRequest.searchTerm = 'LoggedIn';
    anyRequest.loginRecency = 'ANY';
    System.assertEquals(
      1,
      UserAccessMonitorController.getUsers(anyRequest).totalMatchingUsers
    );
  }

  @IsTest
  static void sessionStatusFilterUsesInjectedSessionProvider() {
    User sessionUser = UserAccessMonitorTestDataFactory.buildUser(
      'Has',
      'Session',
      true
    );
    User noSessionUser = UserAccessMonitorTestDataFactory.buildUser(
      'No',
      'Session',
      true
    );
    insert new List<User>{ sessionUser, noSessionUser };
    useFakes(new Set<Id>{ sessionUser.Id });

    UserAccessMonitorRequest activeSessionRequest = new UserAccessMonitorRequest();
    activeSessionRequest.searchTerm = 'Session';
    activeSessionRequest.sessionStatus = 'ACTIVE';
    UserAccessMonitorResponse activeSessionResponse = UserAccessMonitorController.getUsers(
      activeSessionRequest
    );
    System.assertEquals(1, activeSessionResponse.totalMatchingUsers);
    System.assertEquals(sessionUser.Id, activeSessionResponse.rows[0].id);

    UserAccessMonitorRequest noSessionRequest = new UserAccessMonitorRequest();
    noSessionRequest.searchTerm = 'Session';
    noSessionRequest.sessionStatus = 'INACTIVE';
    UserAccessMonitorResponse noSessionResponse = UserAccessMonitorController.getUsers(
      noSessionRequest
    );
    System.assertEquals(1, noSessionResponse.totalMatchingUsers);
    System.assertEquals(noSessionUser.Id, noSessionResponse.rows[0].id);
  }

  @IsTest
  static void sessionDetectionUnsupportedFallsBackGracefully() {
    User activeUser = UserAccessMonitorTestDataFactory.buildUser(
      'Fallback',
      'Case',
      true
    );
    insert activeUser;
    UserAccessMonitorController.permissionChecker = new UserAccessMonitorTestDataFactory.FakePermissionChecker(
      true
    );
    UserAccessMonitorController.sessionProvider = new UserAccessMonitorTestDataFactory.FakeSessionProvider(
      new Set<Id>(),
      false,
      'Active session information is unavailable. Login recency is still shown.'
    );

    UserAccessMonitorRequest request = new UserAccessMonitorRequest();
    request.searchTerm = 'Fallback';
    request.sessionStatus = 'ACTIVE';

    UserAccessMonitorResponse response = UserAccessMonitorController.getUsers(
      request
    );

    System.assertEquals(false, response.sessionDetectionSupported);
    System.assertNotEquals(null, response.warningMessage);
    System.assertEquals(
      1,
      response.totalMatchingUsers,
      'An unusable session filter must be ignored rather than hiding all users.'
    );
    System.assertEquals(false, response.summary.activeSessionUsersAvailable);
    System.assertEquals(
      null,
      response.summary.activeSessionUsers,
      'An unknown count must not be reported as zero.'
    );
    System.assertEquals(false, response.rows[0].activeSessionDetected);
  }

  @IsTest
  static void defaultOrderingPlacesActiveSessionUsersFirstThenActiveThenInactive() {
    String uniqueSuffix =
      'Ord' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
    User sessionUser = UserAccessMonitorTestDataFactory.buildUser(
      'Zed',
      'Session' + uniqueSuffix,
      true
    );
    User activeUser = UserAccessMonitorTestDataFactory.buildUser(
      'Amy',
      'Active' + uniqueSuffix,
      true
    );
    User inactiveUser = UserAccessMonitorTestDataFactory.buildUser(
      'Bob',
      'Inactive' + uniqueSuffix,
      false
    );
    insert new List<User>{ sessionUser, activeUser, inactiveUser };
    useFakes(new Set<Id>{ sessionUser.Id });

    UserAccessMonitorRequest request = new UserAccessMonitorRequest();
    request.searchTerm = uniqueSuffix;

    UserAccessMonitorResponse response = UserAccessMonitorController.getUsers(
      request
    );

    System.assertEquals(3, response.rows.size());
    System.assertEquals(
      sessionUser.Id,
      response.rows[0].id,
      'The active-session user must sort first regardless of name.'
    );
    System.assertEquals(
      activeUser.Id,
      response.rows[1].id,
      'The remaining active user must sort before the inactive user.'
    );
    System.assertEquals(inactiveUser.Id, response.rows[2].id);
  }

  @IsTest
  static void invalidSortFieldAndDirectionFallBackToDefaults() {
    User userOne = UserAccessMonitorTestDataFactory.buildUser(
      'Sort',
      'Alpha',
      true
    );
    User userTwo = UserAccessMonitorTestDataFactory.buildUser(
      'Sort',
      'Beta',
      true
    );
    insert new List<User>{ userOne, userTwo };
    useFakes(new Set<Id>());

    UserAccessMonitorRequest request = new UserAccessMonitorRequest();
    request.searchTerm = 'Sort';
    request.sortField = 'Name DESC NULLS LAST, (SELECT Id FROM Contacts)';
    request.sortDirection = 'DROP TABLE users;';

    UserAccessMonitorResponse response = UserAccessMonitorController.getUsers(
      request
    );

    System.assertEquals(2, response.totalMatchingUsers);
    System.assertEquals(
      userOne.Id,
      response.rows[0].id,
      'An invalid sort field must fall back to the deterministic default order.'
    );
  }

  @IsTest
  static void invalidOrTamperedCursorResetsToFirstPageWithoutError() {
    User onlyUser = UserAccessMonitorTestDataFactory.buildUser(
      'Cursor',
      'Case',
      true
    );
    insert onlyUser;
    useFakes(new Set<Id>());

    UserAccessMonitorRequest request = new UserAccessMonitorRequest();
    request.searchTerm = 'Cursor';
    request.cursor = 'not-a-real-cursor';

    UserAccessMonitorResponse response = UserAccessMonitorController.getUsers(
      request
    );

    System.assertEquals(
      1,
      response.totalMatchingUsers,
      'A malformed cursor must not raise an error or lose results.'
    );
    System.assertEquals(false, response.hasNextPage);
  }

  @IsTest
  static void blankOptionalFieldsAreHandledSafely() {
    User minimalUser = UserAccessMonitorTestDataFactory.buildUser(
      'Minimal',
      'Fields',
      true
    );
    minimalUser.Department = null;
    minimalUser.CompanyName = null;
    insert minimalUser;
    useFakes(new Set<Id>());

    UserAccessMonitorRequest request = new UserAccessMonitorRequest();
    request.searchTerm = 'Minimal';

    UserAccessMonitorResponse response = UserAccessMonitorController.getUsers(
      request
    );

    System.assertEquals(1, response.totalMatchingUsers);
    System.assertEquals(null, response.rows[0].roleName);
    System.assertEquals(0, response.rows[0].directPermissionSetCount);
  }

  @IsTest
  static void emptyResultSetReturnsZeroRowsWithoutError() {
    useFakes(new Set<Id>());

    UserAccessMonitorRequest request = new UserAccessMonitorRequest();
    request.searchTerm = 'NoUserMatchesThisTokenAtAll12345';

    UserAccessMonitorResponse response = UserAccessMonitorController.getUsers(
      request
    );

    System.assertEquals(0, response.totalMatchingUsers);
    System.assertEquals(0, response.rows.size());
    System.assertEquals(false, response.hasNextPage);
  }

  @IsTest
  static void summaryMetricsReflectFilteredResultsNotJustCurrentPage() {
    User activeUser = UserAccessMonitorTestDataFactory.buildUser(
      'Summary',
      'Active',
      true
    );
    User inactiveUser = UserAccessMonitorTestDataFactory.buildUser(
      'Summary',
      'Inactive',
      false
    );
    insert new List<User>{ activeUser, inactiveUser };
    useFakes(new Set<Id>());

    UserAccessMonitorRequest request = new UserAccessMonitorRequest();
    request.searchTerm = 'Summary';

    UserAccessMonitorResponse response = UserAccessMonitorController.getUsers(
      request
    );

    System.assertEquals(2, response.summary.totalMatchingUsers);
    System.assertEquals(1, response.summary.activeUsers);
    System.assertEquals(1, response.summary.inactiveUsers);
  }

  @IsTest
  static void getFilterOptionsReturnsProfileAndRoleOptions() {
    useFakes(new Set<Id>());

    UserAccessMonitorFilterOptionsResponse response = UserAccessMonitorController.getFilterOptions();

    System.assert(
      !response.profiles.isEmpty(),
      'At least the Standard User profile should be returned.'
    );
    System.assertEquals(false, response.profilesTruncated);
  }
}
