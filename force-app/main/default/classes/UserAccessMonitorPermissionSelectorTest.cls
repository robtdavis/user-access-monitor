@IsTest
private class UserAccessMonitorPermissionSelectorTest {
  @IsTest
  static void emptyUserListReturnsEmptyCountsWithoutQuerying() {
    UserAccessMonitorPermissionSelector selector = new UserAccessMonitorPermissionSelector();

    UserAccessMonitorPermissionSelector.Counts counts = selector.findCounts(
      new List<User>()
    );

    System.assertEquals(0, counts.directCounts.size());
    System.assertEquals(0, counts.groupCounts.size());
  }

  @IsTest
  static void directPermissionSetAssignmentIsCountedSeparatelyFromGroups() {
    User assignedUser = UserAccessMonitorTestDataFactory.buildUser(
      'Perm',
      'Direct',
      true
    );
    User unassignedUser = UserAccessMonitorTestDataFactory.buildUser(
      'Perm',
      'None',
      true
    );
    insert new List<User>{ assignedUser, unassignedUser };

    PermissionSet directPermissionSet = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'User_Access_Monitor_Admin'
      LIMIT 1
    ];
    insert new PermissionSetAssignment(
      AssigneeId = assignedUser.Id,
      PermissionSetId = directPermissionSet.Id
    );

    UserAccessMonitorPermissionSelector selector = new UserAccessMonitorPermissionSelector();
    UserAccessMonitorPermissionSelector.Counts counts = selector.findCounts(
      new List<User>{ assignedUser, unassignedUser }
    );

    System.assertEquals(1, counts.directCounts.get(assignedUser.Id));
    System.assertEquals(false, counts.groupCounts.containsKey(assignedUser.Id));
    System.assertEquals(
      false,
      counts.directCounts.containsKey(unassignedUser.Id)
    );
  }

  @IsTest
  static void permissionSetGroupAssignmentIsCountedSeparatelyFromDirectAssignments() {
    User groupUser = UserAccessMonitorTestDataFactory.buildUser(
      'Perm',
      'Group',
      true
    );
    insert groupUser;

    PermissionSet memberPermissionSet = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'User_Access_Monitor_Admin'
      LIMIT 1
    ];
    PermissionSetGroup permissionSetGroup = new PermissionSetGroup(
      DeveloperName = 'UAM_Test_Group_' +
        String.valueOf(Math.abs(Crypto.getRandomInteger())),
      MasterLabel = 'UAM Test Group'
    );
    insert permissionSetGroup;
    insert new PermissionSetGroupComponent(
      PermissionSetGroupId = permissionSetGroup.Id,
      PermissionSetId = memberPermissionSet.Id
    );

    Test.startTest();
    Test.calculatePermissionSetGroup(permissionSetGroup.Id);
    Test.stopTest();

    insert new PermissionSetAssignment(
      AssigneeId = groupUser.Id,
      PermissionSetGroupId = permissionSetGroup.Id
    );

    UserAccessMonitorPermissionSelector selector = new UserAccessMonitorPermissionSelector();
    UserAccessMonitorPermissionSelector.Counts counts = selector.findCounts(
      new List<User>{ groupUser }
    );

    System.assertEquals(1, counts.groupCounts.get(groupUser.Id));
    System.assertEquals(
      false,
      counts.directCounts.containsKey(groupUser.Id),
      'A Permission Set Group assignment must not also be counted as a direct assignment.'
    );
  }
}
