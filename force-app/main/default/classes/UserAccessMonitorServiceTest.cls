@IsTest
private class UserAccessMonitorServiceTest {
  @IsTest
  static void pageSizeIsAlwaysFixedRegardlessOfClientInput() {
    User user = UserAccessMonitorTestDataFactory.buildUser(
      'Page',
      'Size',
      true
    );
    insert user;
    UserAccessMonitorService service = new UserAccessMonitorService(
      new UserAccessMonitorTestDataFactory.FakeSessionProvider(new Set<Id>())
    );

    UserAccessMonitorModels.Request request = new UserAccessMonitorModels.Request();
    request.searchTerm = 'Page';

    UserAccessMonitorModels.Response response = service.getUsers(request);

    System.assertEquals(
      100,
      response.pageSize,
      'Page size must always be the fixed server-controlled value.'
    );
  }

  @IsTest
  static void cursorWithMismatchedFilterFingerprintIsIgnored() {
    User userOne = UserAccessMonitorTestDataFactory.buildUser(
      'Fingerprint',
      'Alpha',
      true
    );
    User userTwo = UserAccessMonitorTestDataFactory.buildUser(
      'Fingerprint',
      'Beta',
      true
    );
    insert new List<User>{ userOne, userTwo };
    UserAccessMonitorService service = new UserAccessMonitorService(
      new UserAccessMonitorTestDataFactory.FakeSessionProvider(new Set<Id>())
    );

    UserAccessMonitorModels.Request firstRequest = new UserAccessMonitorModels.Request();
    firstRequest.searchTerm = 'Fingerprint';
    UserAccessMonitorModels.Response firstResponse = service.getUsers(
      firstRequest
    );

    UserAccessMonitorModels.Request secondRequest = new UserAccessMonitorModels.Request();
    secondRequest.searchTerm = 'Fingerprint Alpha';
    secondRequest.cursor = firstResponse.nextCursor;

    UserAccessMonitorModels.Response secondResponse = service.getUsers(
      secondRequest
    );

    System.assertEquals(
      1,
      secondResponse.totalMatchingUsers,
      'A cursor from a different filter/sort combination must be ignored, not misapplied.'
    );
  }

  @IsTest
  static void sessionStatusFilterIsClampedWhenDetectionIsUnsupported() {
    User user = UserAccessMonitorTestDataFactory.buildUser(
      'Clamped',
      'Case',
      true
    );
    insert user;
    UserAccessMonitorService service = new UserAccessMonitorService(
      new UserAccessMonitorTestDataFactory.FakeSessionProvider(
        new Set<Id>(),
        false,
        'unavailable'
      )
    );

    UserAccessMonitorModels.Request request = new UserAccessMonitorModels.Request();
    request.searchTerm = 'Clamped';
    request.sessionStatus = 'ACTIVE';

    UserAccessMonitorModels.Response response = service.getUsers(request);

    System.assertEquals(
      1,
      response.totalMatchingUsers,
      'sessionStatus=ACTIVE must be ignored, not hide every user, when detection is unsupported.'
    );
  }

  @IsTest
  static void invalidSortDirectionFallsBackToAscending() {
    User userA = UserAccessMonitorTestDataFactory.buildUser(
      'Direction',
      'Alpha',
      true
    );
    User userB = UserAccessMonitorTestDataFactory.buildUser(
      'Direction',
      'Beta',
      true
    );
    insert new List<User>{ userA, userB };
    UserAccessMonitorService service = new UserAccessMonitorService(
      new UserAccessMonitorTestDataFactory.FakeSessionProvider(new Set<Id>())
    );

    UserAccessMonitorModels.Request request = new UserAccessMonitorModels.Request();
    request.searchTerm = 'Direction';
    request.sortField = 'lastName';
    request.sortDirection = 'sideways';

    UserAccessMonitorModels.Response response = service.getUsers(request);

    System.assertEquals(
      userA.Id,
      response.rows[0].id,
      'An invalid direction must fall back to ascending order.'
    );
  }

  @IsTest
  static void hasNextPageIsFalseWhenAllMatchingUsersFitOnOnePage() {
    User user = UserAccessMonitorTestDataFactory.buildUser(
      'OnePage',
      'Case',
      true
    );
    insert user;
    UserAccessMonitorService service = new UserAccessMonitorService(
      new UserAccessMonitorTestDataFactory.FakeSessionProvider(new Set<Id>())
    );

    UserAccessMonitorModels.Request request = new UserAccessMonitorModels.Request();
    request.searchTerm = 'OnePage';

    UserAccessMonitorModels.Response response = service.getUsers(request);

    System.assertEquals(false, response.hasNextPage);
    System.assertEquals(null, response.nextCursor);
  }
}
