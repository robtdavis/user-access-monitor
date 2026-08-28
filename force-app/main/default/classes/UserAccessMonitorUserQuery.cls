public with sharing class UserAccessMonitorUserQuery {
    private static final Map<String, String> SORT_FIELDS = new Map<String, String>{
        'firstName' => 'FirstName', 'lastName' => 'LastName', 'username' => 'Username', 'email' => 'Email',
        'department' => 'Department', 'company' => 'CompanyName', 'userType' => 'UserType', 'isActive' => 'IsActive',
        'lastLoginDate' => 'LastLoginDate', 'createdDate' => 'CreatedDate', 'profileName' => 'Profile.Name', 'roleName' => 'UserRole.Name'
    };

    public List<Profile> findProfiles() {
        return [SELECT Id, Name FROM Profile ORDER BY Name LIMIT 500];
    }

    public List<UserRole> findRoles() {
        return [SELECT Id, Name FROM UserRole ORDER BY Name LIMIT 500];
    }

    public List<User> findUsers(UserAccessMonitor.Criteria criteria, Integer offset) {
        Map<String, Object> binds = buildBinds(criteria);
        binds.put('pageSize', criteria.pageSize);
        binds.put('offset', offset);
        String soql = 'SELECT Id, FirstName, LastName, Username, Email, Department, CompanyName, UserType, IsActive, LastLoginDate, CreatedDate, Profile.Name, UserRole.Name ' +
            'FROM User ' + buildWhereClause(criteria) + ' ORDER BY ' + buildOrderBy(criteria) + ' LIMIT :pageSize OFFSET :offset';
        return Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
    }

    public Integer countMatching(UserAccessMonitor.Criteria criteria) {
        return count(criteria, null);
    }

    public Integer countActive(UserAccessMonitor.Criteria criteria) {
        return count(criteria, 'IsActive = true');
    }

    public Integer countInactive(UserAccessMonitor.Criteria criteria) {
        return count(criteria, 'IsActive = false');
    }

    public Integer countActiveNeverLoggedIn(UserAccessMonitor.Criteria criteria) {
        return count(criteria, 'IsActive = true AND LastLoginDate = null');
    }

    public Integer countActiveNoLoginIn90Days(UserAccessMonitor.Criteria criteria) {
        return count(criteria, 'IsActive = true AND (LastLoginDate < :summarySince OR LastLoginDate = null)');
    }

    public Integer countActiveSessions(UserAccessMonitor.Criteria criteria) {
        if (criteria.activeSessionUserIds.isEmpty()) return 0;
        return count(criteria, 'Id IN :summarySessionIds');
    }

    private Integer count(UserAccessMonitor.Criteria criteria, String additionalCondition) {
        Map<String, Object> binds = buildBinds(criteria);
        String whereClause = buildWhereClause(criteria);
        if (!String.isBlank(additionalCondition)) {
            whereClause += String.isBlank(whereClause) ? 'WHERE ' : ' AND ';
            whereClause += additionalCondition;
            binds.put('summarySince', Datetime.now().addDays(-90));
            binds.put('summarySessionIds', criteria.activeSessionUserIds);
        }
        return (Integer)Database.countQueryWithBinds('SELECT COUNT() FROM User ' + whereClause, binds, AccessLevel.SYSTEM_MODE);
    }

    private static String buildWhereClause(UserAccessMonitor.Criteria criteria) {
        List<String> conditions = new List<String>();
        if (criteria.userStatus == 'ACTIVE') conditions.add('IsActive = true');
        if (criteria.userStatus == 'INACTIVE') conditions.add('IsActive = false');
        if (criteria.sessionStatus == 'ACTIVE') conditions.add('Id IN :activeSessionUserIds');
        if (criteria.sessionStatus == 'INACTIVE') conditions.add('Id NOT IN :activeSessionUserIds');
        if (criteria.profileId != null) conditions.add('ProfileId = :profileId');
        if (criteria.noRole == true) conditions.add('UserRoleId = null');
        if (criteria.roleId != null) conditions.add('UserRoleId = :roleId');
        if (criteria.loginRecency == 'NEVER') conditions.add('LastLoginDate = null');
        if (criteria.loginRecency == 'MORE_THAN_90') conditions.add('(LastLoginDate < :loginSince OR LastLoginDate = null)');
        if (criteria.loginRecency == 'DAYS_7' || criteria.loginRecency == 'DAYS_30' || criteria.loginRecency == 'DAYS_60' || criteria.loginRecency == 'DAYS_90') {
            conditions.add('LastLoginDate >= :loginSince');
        }
        if (!String.isBlank(criteria.searchTerm)) {
            conditions.add('(FirstName LIKE :searchPattern OR LastName LIKE :searchPattern OR Username LIKE :searchPattern OR Email LIKE :searchPattern OR Department LIKE :searchPattern OR CompanyName LIKE :searchPattern OR Profile.Name LIKE :searchPattern OR UserRole.Name LIKE :searchPattern)');
        }
        return conditions.isEmpty() ? '' : 'WHERE ' + String.join(conditions, ' AND ');
    }

    private static String buildOrderBy(UserAccessMonitor.Criteria criteria) {
        if (!SORT_FIELDS.containsKey(criteria.sortField)) {
            return 'IsActive DESC, LastName ASC NULLS LAST, FirstName ASC NULLS LAST, Id ASC';
        }
        String direction = criteria.sortDirection == 'desc' ? 'DESC' : 'ASC';
        return SORT_FIELDS.get(criteria.sortField) + ' ' + direction + ', Id ASC';
    }

    private static Map<String, Object> buildBinds(UserAccessMonitor.Criteria criteria) {
        Map<String, Object> binds = new Map<String, Object>{ 'activeSessionUserIds' => criteria.activeSessionUserIds };
        if (criteria.profileId != null) binds.put('profileId', criteria.profileId);
        if (criteria.roleId != null) binds.put('roleId', criteria.roleId);
        if (!String.isBlank(criteria.searchTerm)) binds.put('searchPattern', '%' + criteria.searchTerm.trim() + '%');
        if (criteria.loginRecency == 'MORE_THAN_90') binds.put('loginSince', Datetime.now().addDays(-90));
        if (criteria.loginRecency == 'DAYS_7') binds.put('loginSince', Datetime.now().addDays(-7));
        if (criteria.loginRecency == 'DAYS_30') binds.put('loginSince', Datetime.now().addDays(-30));
        if (criteria.loginRecency == 'DAYS_60') binds.put('loginSince', Datetime.now().addDays(-60));
        if (criteria.loginRecency == 'DAYS_90') binds.put('loginSince', Datetime.now().addDays(-90));
        return binds;
    }
}
