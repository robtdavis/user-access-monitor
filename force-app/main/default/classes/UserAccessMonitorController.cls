public with sharing class UserAccessMonitorController {
    @TestVisible
    private static SessionProvider sessionProvider = new AuthSessionProvider();
    @TestVisible
    private static Boolean bypassAuthorization = false;

    public interface SessionProvider {
        Set<Id> getActiveUserIds();
        Boolean isSupported();
        String getWarning();
    }

    private class AuthSessionProvider implements SessionProvider {
        private Boolean supported = true;
        private String warning;

        public Set<Id> getActiveUserIds() {
            Set<Id> userIds = new Set<Id>();
            try {
                Datetime activeSince = Datetime.now().addMinutes(-30);
                for (AuthSession sessionRecord : [
                    SELECT UsersId
                    FROM AuthSession
                    WHERE LastModifiedDate >= :activeSince AND UsersId != null
                ]) {
                    userIds.add(sessionRecord.UsersId);
                }
            } catch (Exception exceptionObject) {
                supported = false;
                warning = 'Active session information is unavailable. Login recency is still shown.';
            }
            return userIds;
        }

        public Boolean isSupported() {
            return supported;
        }

        public String getWarning() {
            return warning;
        }
    }

    public class Request {
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public String searchTerm;
        @AuraEnabled public String userStatus;
        @AuraEnabled public String sessionStatus;
        @AuraEnabled public String profileId;
        @AuraEnabled public String roleId;
        @AuraEnabled public String loginRecency;
        @AuraEnabled public String sortField;
        @AuraEnabled public String sortDirection;
    }

    public class Response {
        @AuraEnabled public List<UserRow> rows = new List<UserRow>();
        @AuraEnabled public Integer totalMatchingUsers = 0;
        @AuraEnabled public Integer currentPage;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Integer totalPages = 0;
        @AuraEnabled public SummaryMetrics summary;
        @AuraEnabled public Boolean sessionDetectionSupported;
        @AuraEnabled public String warningMessage;
        @AuraEnabled public String paginationWarning;
    }

    public class SummaryMetrics {
        @AuraEnabled public Integer totalMatchingUsers;
        @AuraEnabled public Integer activeUsers;
        @AuraEnabled public Integer inactiveUsers;
        @AuraEnabled public Integer activeSessionUsers;
        @AuraEnabled public Integer activeNeverLoggedIn;
        @AuraEnabled public Integer activeNoLoginIn90Days;
    }

    public class UserRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String username;
        @AuraEnabled public String email;
        @AuraEnabled public String department;
        @AuraEnabled public String company;
        @AuraEnabled public String userType;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Datetime lastLoginDate;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String profileName;
        @AuraEnabled public String roleName;
        @AuraEnabled public Integer directPermissionSetCount = 0;
        @AuraEnabled public Integer permissionSetGroupCount = 0;
        @AuraEnabled public Boolean activeSessionDetected;
    }

    public class FilterOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public FilterOption(String optionLabel, String optionValue) {
            label = optionLabel;
            value = optionValue;
        }
    }

    public class FilterOptionsResponse {
        @AuraEnabled public List<FilterOption> profiles = new List<FilterOption>();
        @AuraEnabled public List<FilterOption> roles = new List<FilterOption>();
    }

    @AuraEnabled(cacheable=true)
    public static Response getUsers(Request request) {
        authorize();
        return new UserAccessMonitor().load(request, sessionProvider);
    }

    @AuraEnabled(cacheable=true)
    public static FilterOptionsResponse getFilterOptions() {
        authorize();
        return new UserAccessMonitor().loadFilterOptions();
    }

    private static void authorize() {
        if (!bypassAuthorization && !FeatureManagement.checkPermission('View_User_Access_Monitor')) {
            throw new AuraHandledException('You are not authorized to view User Access Monitor.');
        }
    }
}
