@IsTest
private class UserAccessMonitorControllerTest {
    private class FakeSessionProvider implements UserAccessMonitorController.SessionProvider {
        private Set<Id> activeUserIds;
        FakeSessionProvider(Set<Id> ids) { activeUserIds = ids; }
        public Set<Id> getActiveUserIds() { return activeUserIds; }
        public Boolean isSupported() { return true; }
        public String getWarning() { return null; }
    }

    private static User createUser(String suffix, Boolean active) {
        Profile profileRecord = [SELECT Id FROM Profile WHERE UserType = 'Standard' LIMIT 1];
        return new User(
            FirstName = 'Monitor', LastName = 'Test' + suffix, Alias = 'mon' + suffix,
            Email = 'monitor' + suffix + '@example.com', Username = 'monitor' + suffix + '@example.com.' + Test.getRunId(),
            ProfileId = profileRecord.Id, IsActive = active, TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
        );
    }

    @IsTest
    static void authorizedSearchAndFiltersReturnTypedRows() {
        User activeUser = createUser('Active', true);
        User inactiveUser = createUser('Inactive', false);
        insert new List<User>{ activeUser, inactiveUser };
        UserAccessMonitorController.bypassAuthorization = true;
        UserAccessMonitorController.sessionProvider = new FakeSessionProvider(new Set<Id>{ activeUser.Id });
        UserAccessMonitorController.Request request = new UserAccessMonitorController.Request();
        request.searchTerm = 'Monitor TestActive';
        request.userStatus = 'ACTIVE';
        request.loginRecency = 'NEVER';
        request.sortField = 'lastName';
        request.sortDirection = 'desc';
        Test.startTest();
        UserAccessMonitorController.Response response = UserAccessMonitorController.getUsers(request);
        Test.stopTest();
        System.assertEquals(1, response.totalMatchingUsers);
        System.assertEquals(1, response.rows.size());
        System.assertEquals('Active Session Detected', response.rows[0].activeSessionDetected ? 'Active Session Detected' : 'No Active Session Detected');
        System.assertEquals(0, response.rows[0].directPermissionSetCount);
    }

    @IsTest
    static void invalidPagingAndSortAreNormalized() {
        UserAccessMonitorController.bypassAuthorization = true;
        UserAccessMonitorController.sessionProvider = new FakeSessionProvider(new Set<Id>());
        UserAccessMonitorController.Request request = new UserAccessMonitorController.Request();
        request.pageNumber = -4;
        request.pageSize = 1;
        request.sortField = 'Name DESC NULLS LAST, Id';
        request.sortDirection = 'DROP TABLE';
        UserAccessMonitorController.Response response = UserAccessMonitorController.getUsers(request);
        System.assertEquals(100, response.pageSize);
        System.assert(response.currentPage >= 1);
    }

    @IsTest
    static void unauthorizedAccessIsRejected() {
        UserAccessMonitorController.bypassAuthorization = false;
        try {
            UserAccessMonitorController.getFilterOptions();
            System.assert(false, 'Expected authorization failure');
        } catch (AuraHandledException exceptionObject) {
            System.assert(exceptionObject.getMessage().contains('not authorized'));
        }
    }
}
