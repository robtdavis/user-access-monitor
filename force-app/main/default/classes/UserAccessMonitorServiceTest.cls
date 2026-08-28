@IsTest
private class UserAccessMonitorServiceTest {
  @IsTest
  static void allowedPageSizeIsAccepted() {
    User user = UserAccessMonitorTestDataFactory.buildUser(
      'Page',
      'Size',
      true
    );
    insert user;
    UserAccessMonitorService service = new UserAccessMonitorService(
      new UserAccessMonitorTestDataFactory.FakeSessionProvider(new Set<Id>())
    );

    UserAccessMonitorRequest request = new UserAccessMonitorRequest();
    request.searchTerm = 'Page';
    request.pageSize = 50;

    UserAccessMonitorResponse response = service.getUsers(request);

    System.assertEquals(
      50,
      response.pageSize,
      'An allowlisted design-time page size must be accepted.'
    );
  }

  @IsTest
  static void missingOrUnsupportedPageSizeDefaultsToTen() {
    User user = UserAccessMonitorTestDataFactory.buildUser(
      'DefaultPage',
      'Size',
      true
    );
    insert user;
    UserAccessMonitorService service = new UserAccessMonitorService(
      new UserAccessMonitorTestDataFactory.FakeSessionProvider(new Set<Id>())
    );

    UserAccessMonitorRequest request = new UserAccessMonitorRequest();
    request.searchTerm = 'DefaultPage';
    request.pageSize = 37;

    UserAccessMonitorResponse response = service.getUsers(request);

    System.assertEquals(
      10,
      response.pageSize,
      'A missing or unsupported page size must safely default to 10.'
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

    UserAccessMonitorRequest firstRequest = new UserAccessMonitorRequest();
    firstRequest.searchTerm = 'Fingerprint';
    UserAccessMonitorResponse firstResponse = service.getUsers(firstRequest);

    UserAccessMonitorRequest secondRequest = new UserAccessMonitorRequest();
    secondRequest.searchTerm = 'Fingerprint Alpha';
    secondRequest.cursor = firstResponse.nextCursor;

    UserAccessMonitorResponse secondResponse = service.getUsers(secondRequest);

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

    UserAccessMonitorRequest request = new UserAccessMonitorRequest();
    request.searchTerm = 'Clamped';
    request.sessionStatus = 'ACTIVE';

    UserAccessMonitorResponse response = service.getUsers(request);

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

    UserAccessMonitorRequest request = new UserAccessMonitorRequest();
    request.searchTerm = 'Direction';
    request.sortField = 'lastName';
    request.sortDirection = 'sideways';

    UserAccessMonitorResponse response = service.getUsers(request);

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

    UserAccessMonitorRequest request = new UserAccessMonitorRequest();
    request.searchTerm = 'OnePage';

    UserAccessMonitorResponse response = service.getUsers(request);

    System.assertEquals(false, response.hasNextPage);
    System.assertEquals(null, response.nextCursor);
  }
}
