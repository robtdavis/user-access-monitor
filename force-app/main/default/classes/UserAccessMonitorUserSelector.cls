/**
 * All User, Profile, and UserRole querying for the User Access Monitor feature. Owns
 * WHERE/ORDER BY construction and keyset (cursor-based) pagination so no other class
 * builds dynamic SOQL against these objects.
 *
 * Pagination design: rather than SOQL OFFSET (capped at 2,000 rows and silently returning
 * nothing beyond that), every query here is keyset-paginated: it filters to rows that sort
 * strictly after the last row the caller has already seen, then LIMITs the result. This
 * scales to orgs with tens of thousands of users because the query cost does not grow with
 * how deep into the result set the caller has paged.
 *
 * The default (session-first) ordering cannot be expressed as a single ORDER BY, because
 * "has an active session" is not a field on User. It is implemented as two ordered buckets -
 * active-session users, then everyone else ordered by IsActive DESC, LastName, FirstName -
 * each independently keyset-paginated, concatenated in that fixed order. A page can therefore
 * require up to two queries instead of one; this is a deliberate, documented tradeoff for
 * correct, scalable session-first ordering.
 */
public with sharing class UserAccessMonitorUserSelector {
  private static final Integer OPTION_LIMIT = 2000;

  private static final String SELECT_FIELDS =
    'SELECT Id, FirstName, LastName, Username, Email, Department, CompanyName, UserType, ' +
    'IsActive, LastLoginDate, CreatedDate, Profile.Name, UserRole.Name';

  private static final Map<String, String> SORT_FIELDS = new Map<String, String>{
    'firstName' => 'FirstName',
    'lastName' => 'LastName',
    'username' => 'Username',
    'email' => 'Email',
    'department' => 'Department',
    'company' => 'CompanyName',
    'userType' => 'UserType',
    'isActive' => 'IsActive',
    'lastLoginDate' => 'LastLoginDate',
    'createdDate' => 'CreatedDate',
    'profileName' => 'Profile.Name',
    'roleName' => 'UserRole.Name'
  };

  private static final Map<String, String> SORT_FIELD_TYPES = new Map<String, String>{
    'firstName' => 'STRING',
    'lastName' => 'STRING',
    'username' => 'STRING',
    'email' => 'STRING',
    'department' => 'STRING',
    'company' => 'STRING',
    'userType' => 'STRING',
    'isActive' => 'BOOLEAN',
    'lastLoginDate' => 'DATETIME',
    'createdDate' => 'DATETIME',
    'profileName' => 'STRING',
    'roleName' => 'STRING'
  };

  public static Boolean isSortFieldSupported(String sortField) {
    return SORT_FIELDS.containsKey(sortField);
  }

  public UserAccessMonitorModels.ProfileOptionsResult findProfiles() {
    Integer queryLimit = OPTION_LIMIT + 1;
    List<Profile> records = [
      SELECT Id, Name
      FROM Profile
      ORDER BY Name
      LIMIT :queryLimit
    ];
    UserAccessMonitorModels.ProfileOptionsResult result = new UserAccessMonitorModels.ProfileOptionsResult();
    result.truncated = records.size() > OPTION_LIMIT;
    if (result.truncated) {
      records.remove(records.size() - 1);
    }
    result.records = records;
    return result;
  }

  public UserAccessMonitorModels.RoleOptionsResult findRoles() {
    Integer queryLimit = OPTION_LIMIT + 1;
    List<UserRole> records = [
      SELECT Id, Name
      FROM UserRole
      ORDER BY Name
      LIMIT :queryLimit
    ];
    UserAccessMonitorModels.RoleOptionsResult result = new UserAccessMonitorModels.RoleOptionsResult();
    result.truncated = records.size() > OPTION_LIMIT;
    if (result.truncated) {
      records.remove(records.size() - 1);
    }
    result.records = records;
    return result;
  }

  /** Session-first default ordering, paginated across the two ordering buckets. */
  public UserAccessMonitorModels.UserPageResult findDefaultOrder(
    UserAccessMonitorModels.Criteria criteria
  ) {
    Integer fetchSize = criteria.pageSize + 1;
    UserAccessMonitorModels.Cursor cursor = criteria.afterCursor;

    List<User> bucket1Rows = new List<User>();
    Boolean shouldQueryBucket1 =
      criteria.sessionStatus != 'INACTIVE' &&
      (cursor == null ||
      cursor.bucket == 'SESSION');
    if (shouldQueryBucket1) {
      Map<String, Object> keysetBinds = new Map<String, Object>();
      String keysetCondition = (cursor != null &&
        cursor.bucket == 'SESSION')
        ? buildBucket1KeysetCondition(cursor, keysetBinds)
        : null;
      bucket1Rows = queryBucket(
        criteria,
        true,
        'LastName ASC, FirstName ASC, Id ASC',
        keysetCondition,
        keysetBinds,
        fetchSize
      );
    }

    List<User> bucket2Rows = new List<User>();
    if (bucket1Rows.size() < fetchSize && criteria.sessionStatus != 'ACTIVE') {
      Integer remaining = fetchSize - bucket1Rows.size();
      Map<String, Object> keysetBinds = new Map<String, Object>();
      String keysetCondition = (cursor != null &&
        cursor.bucket == 'OTHER')
        ? buildBucket2KeysetCondition(cursor, keysetBinds)
        : null;
      bucket2Rows = queryBucket(
        criteria,
        false,
        'IsActive DESC, LastName ASC, FirstName ASC, Id ASC',
        keysetCondition,
        keysetBinds,
        remaining
      );
    }

    List<User> combined = new List<User>();
    combined.addAll(bucket1Rows);
    combined.addAll(bucket2Rows);

    UserAccessMonitorModels.UserPageResult result = new UserAccessMonitorModels.UserPageResult();
    result.hasNextPage = combined.size() > criteria.pageSize;
    if (result.hasNextPage) {
      combined.remove(combined.size() - 1);
    }
    result.records = combined;
    if (result.hasNextPage) {
      User lastRow = combined[combined.size() - 1];
      Boolean lastFromBucket1 = combined.size() - 1 < bucket1Rows.size();
      UserAccessMonitorModels.Cursor nextCursor = new UserAccessMonitorModels.Cursor();
      nextCursor.lastLastName = lastRow.LastName;
      nextCursor.lastFirstName = lastRow.FirstName;
      nextCursor.lastId = lastRow.Id;
      nextCursor.bucket = lastFromBucket1 ? 'SESSION' : 'OTHER';
      if (!lastFromBucket1) {
        nextCursor.lastIsActive = lastRow.IsActive;
      }
      result.nextCursor = nextCursor;
    }
    return result;
  }

  /** Single-field keyset ordering for an explicitly chosen, allowlisted sort column. */
  public UserAccessMonitorModels.UserPageResult findBySortField(
    UserAccessMonitorModels.Criteria criteria
  ) {
    Integer fetchSize = criteria.pageSize + 1;
    String soqlField = SORT_FIELDS.get(criteria.sortField);
    String direction = criteria.sortDirection == 'desc' ? 'DESC' : 'ASC';

    Map<String, Object> binds = buildBinds(criteria);
    String whereClause = buildWhereClause(criteria);
    if (criteria.afterCursor != null) {
      Object lastValue = parseSortValue(
        criteria.sortField,
        criteria.afterCursor.lastSortValue
      );
      String keysetCondition = buildKeysetCondition(
        new List<String>{ soqlField },
        new List<String>{ direction },
        new List<Object>{ lastValue },
        criteria.afterCursor.lastId,
        binds
      );
      whereClause += String.isBlank(whereClause)
        ? ('WHERE ' + keysetCondition)
        : (' AND ' + keysetCondition);
    }
    binds.put('limitSize', fetchSize);
    String soql =
      SELECT_FIELDS +
      ' FROM User ' +
      whereClause +
      ' ORDER BY ' +
      soqlField +
      ' ' +
      direction +
      ' NULLS LAST, Id ASC LIMIT :limitSize';
    List<User> rows = Database.queryWithBinds(
      soql,
      binds,
      AccessLevel.SYSTEM_MODE
    );

    UserAccessMonitorModels.UserPageResult result = new UserAccessMonitorModels.UserPageResult();
    result.hasNextPage = rows.size() > criteria.pageSize;
    if (result.hasNextPage) {
      rows.remove(rows.size() - 1);
    }
    result.records = rows;
    if (result.hasNextPage) {
      User lastRow = rows[rows.size() - 1];
      UserAccessMonitorModels.Cursor nextCursor = new UserAccessMonitorModels.Cursor();
      nextCursor.lastId = lastRow.Id;
      nextCursor.lastSortValue = serializeSortValue(
        criteria.sortField,
        extractSortValue(criteria.sortField, lastRow)
      );
      result.nextCursor = nextCursor;
    }
    return result;
  }

  public Integer countMatching(UserAccessMonitorModels.Criteria criteria) {
    return count(criteria, null);
  }

  public Integer countActive(UserAccessMonitorModels.Criteria criteria) {
    return count(criteria, 'IsActive = true');
  }

  public Integer countInactive(UserAccessMonitorModels.Criteria criteria) {
    return count(criteria, 'IsActive = false');
  }

  public Integer countActiveNeverLoggedIn(
    UserAccessMonitorModels.Criteria criteria
  ) {
    return count(criteria, 'IsActive = true AND LastLoginDate = null');
  }

  public Integer countActiveNoLoginIn90Days(
    UserAccessMonitorModels.Criteria criteria
  ) {
    return count(
      criteria,
      'IsActive = true AND (LastLoginDate < :summarySince OR LastLoginDate = null)'
    );
  }

  public Integer countActiveSessions(
    UserAccessMonitorModels.Criteria criteria
  ) {
    if (criteria.activeSessionUserIds.isEmpty())
      return 0;
    return count(criteria, 'Id IN :summarySessionIds');
  }

  private List<User> queryBucket(
    UserAccessMonitorModels.Criteria criteria,
    Boolean sessionBucket,
    String orderBy,
    String keysetCondition,
    Map<String, Object> keysetBinds,
    Integer limitSize
  ) {
    Map<String, Object> binds = buildBinds(criteria);
    binds.putAll(keysetBinds);
    String whereClause = buildWhereClause(criteria);
    if (criteria.sessionStatus == 'ALL') {
      String bucketCondition = sessionBucket
        ? 'Id IN :activeSessionUserIds'
        : 'Id NOT IN :activeSessionUserIds';
      whereClause += String.isBlank(whereClause)
        ? ('WHERE ' + bucketCondition)
        : (' AND ' + bucketCondition);
    }
    if (!String.isBlank(keysetCondition)) {
      whereClause += String.isBlank(whereClause)
        ? ('WHERE ' + keysetCondition)
        : (' AND ' + keysetCondition);
    }
    binds.put('limitSize', limitSize);
    String soql =
      SELECT_FIELDS +
      ' FROM User ' +
      whereClause +
      ' ORDER BY ' +
      orderBy +
      ' LIMIT :limitSize';
    return Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
  }

  private String buildBucket1KeysetCondition(
    UserAccessMonitorModels.Cursor cursor,
    Map<String, Object> binds
  ) {
    return buildKeysetCondition(
      new List<String>{ 'LastName', 'FirstName' },
      new List<String>{ 'ASC', 'ASC' },
      new List<Object>{ cursor.lastLastName, cursor.lastFirstName },
      cursor.lastId,
      binds
    );
  }

  private String buildBucket2KeysetCondition(
    UserAccessMonitorModels.Cursor cursor,
    Map<String, Object> binds
  ) {
    return buildKeysetCondition(
      new List<String>{ 'IsActive', 'LastName', 'FirstName' },
      new List<String>{ 'DESC', 'ASC', 'ASC' },
      new List<Object>{
        cursor.lastIsActive,
        cursor.lastLastName,
        cursor.lastFirstName
      },
      cursor.lastId,
      binds
    );
  }

  private Integer count(
    UserAccessMonitorModels.Criteria criteria,
    String additionalCondition
  ) {
    Map<String, Object> binds = buildBinds(criteria);
    String whereClause = buildWhereClause(criteria);
    if (!String.isBlank(additionalCondition)) {
      whereClause += String.isBlank(whereClause) ? 'WHERE ' : ' AND ';
      whereClause += additionalCondition;
      binds.put('summarySince', Datetime.now().addDays(-90));
      binds.put('summarySessionIds', criteria.activeSessionUserIds);
    }
    return (Integer) Database.countQueryWithBinds(
      'SELECT COUNT() FROM User ' + whereClause,
      binds,
      AccessLevel.SYSTEM_MODE
    );
  }

  private static String buildWhereClause(
    UserAccessMonitorModels.Criteria criteria
  ) {
    List<String> conditions = new List<String>();
    if (criteria.userStatus == 'ACTIVE')
      conditions.add('IsActive = true');
    if (criteria.userStatus == 'INACTIVE')
      conditions.add('IsActive = false');
    if (criteria.sessionStatus == 'ACTIVE')
      conditions.add('Id IN :activeSessionUserIds');
    if (criteria.sessionStatus == 'INACTIVE')
      conditions.add('Id NOT IN :activeSessionUserIds');
    if (criteria.profileId != null)
      conditions.add('ProfileId = :profileId');
    if (criteria.noRole == true)
      conditions.add('UserRoleId = null');
    if (criteria.roleId != null)
      conditions.add('UserRoleId = :roleId');
    if (criteria.loginRecency == 'NEVER')
      conditions.add('LastLoginDate = null');
    if (criteria.loginRecency == 'MORE_THAN_90')
      conditions.add('(LastLoginDate < :loginSince OR LastLoginDate = null)');
    if (
      criteria.loginRecency == 'DAYS_7' ||
      criteria.loginRecency == 'DAYS_30' ||
      criteria.loginRecency == 'DAYS_60' ||
      criteria.loginRecency == 'DAYS_90'
    ) {
      conditions.add('LastLoginDate >= :loginSince');
    }
    if (!String.isBlank(criteria.searchTerm)) {
      conditions.add(
        '(FirstName LIKE :searchPattern OR LastName LIKE :searchPattern OR Username LIKE :searchPattern OR ' +
          'Email LIKE :searchPattern OR Department LIKE :searchPattern OR CompanyName LIKE :searchPattern OR ' +
          'Profile.Name LIKE :searchPattern OR UserRole.Name LIKE :searchPattern OR ' +
          '(FirstName LIKE :searchFirstPattern AND LastName LIKE :searchLastPattern))'
      );
    }
    return conditions.isEmpty()
      ? ''
      : 'WHERE ' + String.join(conditions, ' AND ');
  }

  private static Map<String, Object> buildBinds(
    UserAccessMonitorModels.Criteria criteria
  ) {
    Map<String, Object> binds = new Map<String, Object>{
      'activeSessionUserIds' => criteria.activeSessionUserIds
    };
    if (criteria.profileId != null)
      binds.put('profileId', criteria.profileId);
    if (criteria.roleId != null)
      binds.put('roleId', criteria.roleId);
    if (!String.isBlank(criteria.searchTerm)) {
      String escaped = escapeLike(criteria.searchTerm.trim());
      binds.put('searchPattern', '%' + escaped + '%');
      List<String> nameParts = criteria.searchTerm.trim().split('\\s+');
      String firstPart = escapeLike(nameParts[0]);
      String lastPart = nameParts.size() > 1
        ? escapeLike(nameParts[nameParts.size() - 1])
        : firstPart;
      binds.put('searchFirstPattern', '%' + firstPart + '%');
      binds.put('searchLastPattern', '%' + lastPart + '%');
    }
    if (criteria.loginRecency == 'MORE_THAN_90')
      binds.put('loginSince', Datetime.now().addDays(-90));
    if (criteria.loginRecency == 'DAYS_7')
      binds.put('loginSince', Datetime.now().addDays(-7));
    if (criteria.loginRecency == 'DAYS_30')
      binds.put('loginSince', Datetime.now().addDays(-30));
    if (criteria.loginRecency == 'DAYS_60')
      binds.put('loginSince', Datetime.now().addDays(-60));
    if (criteria.loginRecency == 'DAYS_90')
      binds.put('loginSince', Datetime.now().addDays(-90));
    return binds;
  }

  /** Escapes SOQL LIKE wildcard and escape characters so search input cannot alter the pattern. */
  private static String escapeLike(String value) {
    return value.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_');
  }

  private static Object extractSortValue(String field, User row) {
    if (field == 'firstName')
      return row.FirstName;
    if (field == 'lastName')
      return row.LastName;
    if (field == 'username')
      return row.Username;
    if (field == 'email')
      return row.Email;
    if (field == 'department')
      return row.Department;
    if (field == 'company')
      return row.CompanyName;
    if (field == 'userType')
      return row.UserType;
    if (field == 'isActive')
      return row.IsActive;
    if (field == 'lastLoginDate')
      return row.LastLoginDate;
    if (field == 'createdDate')
      return row.CreatedDate;
    if (field == 'profileName')
      return row.Profile == null ? null : row.Profile.Name;
    if (field == 'roleName')
      return row.UserRole == null ? null : row.UserRole.Name;
    return null;
  }

  private static String serializeSortValue(String field, Object value) {
    if (value == null)
      return null;
    if (SORT_FIELD_TYPES.get(field) == 'DATETIME')
      return String.valueOf(((Datetime) value).getTime());
    return String.valueOf(value);
  }

  private static Object parseSortValue(String field, String storedValue) {
    if (storedValue == null)
      return null;
    String type = SORT_FIELD_TYPES.get(field);
    if (type == 'DATETIME')
      return Datetime.newInstance(Long.valueOf(storedValue));
    if (type == 'BOOLEAN')
      return Boolean.valueOf(storedValue);
    return storedValue;
  }

  /**
   * Builds a null-safe, lexicographic "strictly after the given key tuple" WHERE fragment
   * for keyset pagination. Nulls are always treated as sorting last, independent of the
   * requested direction, matching the ORDER BY ... NULLS LAST used by the corresponding query.
   */
  private static String buildKeysetCondition(
    List<String> fields,
    List<String> directions,
    List<Object> values,
    Id lastId,
    Map<String, Object> binds
  ) {
    Integer keyCount = fields.size();
    List<String> orTerms = new List<String>();
    for (Integer i = 0; i < keyCount; i++) {
      String afterFragment = afterFragment(
        fields[i],
        directions[i],
        values[i],
        'kgt' + i,
        binds
      );
      if (afterFragment == null) {
        continue;
      }
      List<String> andTerms = new List<String>();
      for (Integer j = 0; j < i; j++) {
        andTerms.add(
          equalsFragment(fields[j], values[j], 'keq' + i + '_' + j, binds)
        );
      }
      andTerms.add(afterFragment);
      orTerms.add('(' + String.join(andTerms, ' AND ') + ')');
    }
    List<String> finalEqualityTerms = new List<String>();
    for (Integer j = 0; j < keyCount; j++) {
      finalEqualityTerms.add(
        equalsFragment(fields[j], values[j], 'keqf' + j, binds)
      );
    }
    binds.put('klastid', lastId);
    finalEqualityTerms.add('Id > :klastid');
    orTerms.add('(' + String.join(finalEqualityTerms, ' AND ') + ')');
    return '(' + String.join(orTerms, ' OR ') + ')';
  }

  private static String equalsFragment(
    String field,
    Object value,
    String bindName,
    Map<String, Object> binds
  ) {
    if (value == null)
      return field + ' = null';
    binds.put(bindName, value);
    return field + ' = :' + bindName;
  }

  /**
   * Returns null when nothing can sort strictly after the given value under NULLS LAST.
   * Boolean fields (only IsActive) cannot use &lt;/&gt; in SOQL, so they are compared by
   * stepping to the single next value in the requested direction instead.
   */
  private static String afterFragment(
    String field,
    String direction,
    Object value,
    String bindName,
    Map<String, Object> binds
  ) {
    if (value == null)
      return null;
    if (value instanceof Boolean) {
      Boolean currentValue = (Boolean) value;
      Boolean nextValue = direction == 'DESC' ? false : true;
      if (currentValue == nextValue) {
        return null;
      }
      binds.put(bindName, nextValue);
      return '(' + field + ' = :' + bindName + ')';
    }
    String operatorSymbol = direction == 'DESC' ? '<' : '>';
    binds.put(bindName, value);
    return '((' +
      field +
      ' ' +
      operatorSymbol +
      ' :' +
      bindName +
      ') OR (' +
      field +
      ' = null))';
  }
}
