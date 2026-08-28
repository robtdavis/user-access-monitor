public with sharing class UserAccessMonitor {
    private static final Integer DEFAULT_PAGE_SIZE = 100;
    private static final Integer MAX_OFFSET = 2000;

    private UserAccessMonitorUserQuery userQuery;
    private UserAccessMonitorPermissionQuery permissionQuery;

    public UserAccessMonitor() {
        userQuery = new UserAccessMonitorUserQuery();
        permissionQuery = new UserAccessMonitorPermissionQuery();
    }

    @TestVisible
    UserAccessMonitor(UserAccessMonitorUserQuery userQuery, UserAccessMonitorPermissionQuery permissionQuery) {
        this.userQuery = userQuery;
        this.permissionQuery = permissionQuery;
    }

    public UserAccessMonitorController.Response load(
        UserAccessMonitorController.Request request,
        UserAccessMonitorController.SessionProvider sessionProvider
    ) {
        Criteria criteria = normalize(request);
        Set<Id> sessionUserIds = sessionProvider.getActiveUserIds();
        UserAccessMonitorController.Response response = new UserAccessMonitorController.Response();
        response.sessionDetectionSupported = sessionProvider.isSupported();
        response.warningMessage = sessionProvider.getWarning();

        criteria.activeSessionUserIds = sessionUserIds;
        response.totalMatchingUsers = userQuery.countMatching(criteria);
        response.pageSize = criteria.pageSize;
        response.totalPages = response.totalMatchingUsers == 0
            ? 0
            : (Integer)Math.ceil((Decimal)response.totalMatchingUsers / criteria.pageSize);
        response.currentPage = Math.min(criteria.pageNumber, Math.max(1, response.totalPages));
        response.summary = buildSummary(criteria, response.totalMatchingUsers);

        Integer offset = (response.currentPage - 1) * criteria.pageSize;
        if (offset > MAX_OFFSET) {
            response.paginationWarning = 'This organization has more than 2,000 matching users. Use search or filters to reach a smaller result set.';
            return response;
        }

        List<User> users = userQuery.findUsers(criteria, offset);
        UserAccessMonitorPermissionQuery.Counts counts = permissionQuery.findCounts(users);
        for (User userRecord : users) {
            response.rows.add(toRow(userRecord, counts, sessionUserIds, response.sessionDetectionSupported));
        }
        return response;
    }

    public UserAccessMonitorController.FilterOptionsResponse loadFilterOptions() {
        UserAccessMonitorController.FilterOptionsResponse response = new UserAccessMonitorController.FilterOptionsResponse();
        for (Profile profileRecord : userQuery.findProfiles()) {
            response.profiles.add(new UserAccessMonitorController.FilterOption(profileRecord.Name, profileRecord.Id));
        }
        for (UserRole roleRecord : userQuery.findRoles()) {
            response.roles.add(new UserAccessMonitorController.FilterOption(roleRecord.Name, roleRecord.Id));
        }
        return response;
    }

    private UserAccessMonitorController.SummaryMetrics buildSummary(Criteria criteria, Integer total) {
        UserAccessMonitorController.SummaryMetrics summary = new UserAccessMonitorController.SummaryMetrics();
        summary.totalMatchingUsers = total;
        summary.activeUsers = userQuery.countActive(criteria);
        summary.inactiveUsers = userQuery.countInactive(criteria);
        summary.activeNeverLoggedIn = userQuery.countActiveNeverLoggedIn(criteria);
        summary.activeNoLoginIn90Days = userQuery.countActiveNoLoginIn90Days(criteria);
        summary.activeSessionUsers = userQuery.countActiveSessions(criteria);
        return summary;
    }

    private static UserAccessMonitorController.UserRow toRow(
        User userRecord,
        UserAccessMonitorPermissionQuery.Counts counts,
        Set<Id> sessionUserIds,
        Boolean sessionSupported
    ) {
        UserAccessMonitorController.UserRow row = new UserAccessMonitorController.UserRow();
        row.id = userRecord.Id;
        row.firstName = userRecord.FirstName;
        row.lastName = userRecord.LastName;
        row.username = userRecord.Username;
        row.email = userRecord.Email;
        row.department = userRecord.Department;
        row.company = userRecord.CompanyName;
        row.userType = userRecord.UserType;
        row.isActive = userRecord.IsActive;
        row.lastLoginDate = userRecord.LastLoginDate;
        row.createdDate = userRecord.CreatedDate;
        row.profileName = userRecord.Profile == null ? null : userRecord.Profile.Name;
        row.roleName = userRecord.UserRole == null ? null : userRecord.UserRole.Name;
        row.directPermissionSetCount = counts.directCounts.containsKey(userRecord.Id) ? counts.directCounts.get(userRecord.Id) : 0;
        row.permissionSetGroupCount = counts.groupCounts.containsKey(userRecord.Id) ? counts.groupCounts.get(userRecord.Id) : 0;
        row.activeSessionDetected = sessionSupported && sessionUserIds.contains(userRecord.Id);
        return row;
    }

    public class Criteria {
        public Integer pageNumber;
        public Integer pageSize;
        public String searchTerm;
        public String userStatus;
        public String sessionStatus;
        public Id profileId;
        public Id roleId;
        public Boolean noRole;
        public String loginRecency;
        public String sortField;
        public String sortDirection;
        public Set<Id> activeSessionUserIds = new Set<Id>();
    }

    private static Criteria normalize(UserAccessMonitorController.Request request) {
        Criteria criteria = new Criteria();
        criteria.pageNumber = request == null || request.pageNumber == null || request.pageNumber < 1 ? 1 : request.pageNumber;
        criteria.pageSize = request == null || request.pageSize != 100 ? DEFAULT_PAGE_SIZE : request.pageSize;
        criteria.searchTerm = request == null ? null : request.searchTerm;
        criteria.userStatus = request == null || String.isBlank(request.userStatus) ? 'ALL' : request.userStatus;
        criteria.sessionStatus = request == null || String.isBlank(request.sessionStatus) ? 'ALL' : request.sessionStatus;
        criteria.loginRecency = request == null || String.isBlank(request.loginRecency) ? 'ANY' : request.loginRecency;
        criteria.sortField = request == null || String.isBlank(request.sortField) ? 'DEFAULT' : request.sortField;
        criteria.sortDirection = request != null && request.sortDirection == 'desc' ? 'desc' : 'asc';
        if (request != null) {
            criteria.profileId = parseId(request.profileId);
            criteria.noRole = request.roleId == 'NONE';
            criteria.roleId = criteria.noRole ? null : parseId(request.roleId);
        }
        return criteria;
    }

    private static Id parseId(String value) {
        if (String.isBlank(value)) return null;
        try {
            return (Id)value;
        } catch (Exception exceptionObject) {
            return null;
        }
    }
}
