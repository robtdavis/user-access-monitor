/**
 * Application service for the User Access Monitor feature. Normalizes and validates
 * requests, coordinates the selectors and the session provider, calculates summary
 * metrics, and assembles the response rows. Contains no SOQL and no dynamic query text -
 * all persistence access goes through UserAccessMonitorUserSelector and
 * UserAccessMonitorPermissionSelector.
 */
public with sharing class UserAccessMonitorService {
  private static final Integer DEFAULT_PAGE_SIZE = 10;
  private static final Set<Integer> ALLOWED_PAGE_SIZES = new Set<Integer>{
    10,
    50,
    100,
    200
  };

  private UserAccessMonitorUserSelector userSelector;
  private UserAccessMonitorPermissionSelector permissionSelector;
  private UserAccessMonitorModels.SessionProvider sessionProvider;

  public UserAccessMonitorService(
    UserAccessMonitorModels.SessionProvider sessionProvider
  ) {
    this(
      new UserAccessMonitorUserSelector(),
      new UserAccessMonitorPermissionSelector(),
      sessionProvider
    );
  }

  @TestVisible
  UserAccessMonitorService(
    UserAccessMonitorUserSelector userSelector,
    UserAccessMonitorPermissionSelector permissionSelector,
    UserAccessMonitorModels.SessionProvider sessionProvider
  ) {
    this.userSelector = userSelector;
    this.permissionSelector = permissionSelector;
    this.sessionProvider = sessionProvider;
  }

  public UserAccessMonitorResponse getUsers(UserAccessMonitorRequest request) {
    Set<Id> sessionUserIds = sessionProvider.getActiveUserIds();
    Boolean sessionSupported = sessionProvider.isSupported();

    UserAccessMonitorModels.Criteria criteria = normalize(
      request,
      sessionSupported
    );
    criteria.activeSessionUserIds = sessionUserIds;
    criteria.afterCursor = resolveCursor(request, criteria);

    UserAccessMonitorResponse response = new UserAccessMonitorResponse();
    response.sessionDetectionSupported = sessionSupported;
    response.warningMessage = sessionProvider.getWarning();
    response.pageSize = criteria.pageSize;
    response.totalMatchingUsers = userSelector.countMatching(criteria);
    response.summary = buildSummary(
      criteria,
      response.totalMatchingUsers,
      sessionSupported
    );

    UserAccessMonitorModels.UserPageResult page = criteria.sortField ==
      'DEFAULT'
      ? userSelector.findDefaultOrder(criteria)
      : userSelector.findBySortField(criteria);

    response.hasNextPage = page.hasNextPage;
    if (page.nextCursor != null) {
      page.nextCursor.fingerprint = buildFingerprint(criteria);
    }
    response.nextCursor = encodeCursor(page.nextCursor);

    UserAccessMonitorPermissionSelector.Counts counts = permissionSelector.findCounts(
      page.records
    );
    for (User userRecord : page.records) {
      response.rows.add(
        toRow(userRecord, counts, sessionUserIds, sessionSupported)
      );
    }
    return response;
  }

  public UserAccessMonitorFilterOptionsResponse getFilterOptions() {
    UserAccessMonitorFilterOptionsResponse response = new UserAccessMonitorFilterOptionsResponse();
    UserAccessMonitorModels.ProfileOptionsResult profileResult = userSelector.findProfiles();
    for (Profile profileRecord : profileResult.records) {
      response.profiles.add(
        new UserAccessMonitorFilterOption(profileRecord.Name, profileRecord.Id)
      );
    }
    response.profilesTruncated = profileResult.truncated;

    UserAccessMonitorModels.RoleOptionsResult roleResult = userSelector.findRoles();
    for (UserRole roleRecord : roleResult.records) {
      response.roles.add(
        new UserAccessMonitorFilterOption(roleRecord.Name, roleRecord.Id)
      );
    }
    response.rolesTruncated = roleResult.truncated;
    return response;
  }

  private UserAccessMonitorSummaryMetrics buildSummary(
    UserAccessMonitorModels.Criteria criteria,
    Integer total,
    Boolean sessionSupported
  ) {
    UserAccessMonitorSummaryMetrics summary = new UserAccessMonitorSummaryMetrics();
    summary.totalMatchingUsers = total;
    summary.activeUsers = userSelector.countActive(criteria);
    summary.inactiveUsers = userSelector.countInactive(criteria);
    summary.activeNeverLoggedIn = userSelector.countActiveNeverLoggedIn(
      criteria
    );
    summary.activeNoLoginIn90Days = userSelector.countActiveNoLoginIn90Days(
      criteria
    );
    summary.activeSessionUsersAvailable = sessionSupported;
    summary.activeSessionUsers = sessionSupported
      ? userSelector.countActiveSessions(criteria)
      : null;
    return summary;
  }

  private static UserAccessMonitorUserRow toRow(
    User userRecord,
    UserAccessMonitorPermissionSelector.Counts counts,
    Set<Id> sessionUserIds,
    Boolean sessionSupported
  ) {
    UserAccessMonitorUserRow row = new UserAccessMonitorUserRow();
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
    row.profileName = userRecord.Profile == null
      ? null
      : userRecord.Profile.Name;
    row.roleName = userRecord.UserRole == null
      ? null
      : userRecord.UserRole.Name;
    row.directPermissionSetCount = counts.directCounts.containsKey(
        userRecord.Id
      )
      ? counts.directCounts.get(userRecord.Id)
      : 0;
    row.permissionSetGroupCount = counts.groupCounts.containsKey(userRecord.Id)
      ? counts.groupCounts.get(userRecord.Id)
      : 0;
    row.activeSessionDetected =
      sessionSupported && sessionUserIds.contains(userRecord.Id);
    return row;
  }

  /** Normalizes and validates the incoming request into safe, allowlisted criteria values. */
  private static UserAccessMonitorModels.Criteria normalize(
    UserAccessMonitorRequest request,
    Boolean sessionSupported
  ) {
    UserAccessMonitorModels.Criteria criteria = new UserAccessMonitorModels.Criteria();
    criteria.pageSize = request != null &&
      ALLOWED_PAGE_SIZES.contains(request.pageSize)
      ? request.pageSize
      : DEFAULT_PAGE_SIZE;
    criteria.searchTerm = request == null ? null : request.searchTerm;
    criteria.userStatus = request == null || String.isBlank(request.userStatus)
      ? 'ALL'
      : request.userStatus;
    criteria.loginRecency = request == null ||
      String.isBlank(request.loginRecency)
      ? 'ANY'
      : request.loginRecency;

    String requestedSortField = request == null ? null : request.sortField;
    Boolean sortFieldIsValid =
      requestedSortField == 'DEFAULT' ||
      UserAccessMonitorUserSelector.isSortFieldSupported(requestedSortField);
    criteria.sortField = sortFieldIsValid ? requestedSortField : 'DEFAULT';
    criteria.sortDirection = request != null &&
      request.sortDirection == 'desc'
      ? 'desc'
      : 'asc';

    String requestedSessionStatus = request == null ||
      String.isBlank(request.sessionStatus)
      ? 'ALL'
      : request.sessionStatus;
    // Filtering by session status would be misleading when session detection is unsupported,
    // since every user would appear to have "no active session" rather than "unknown".
    criteria.sessionStatus = sessionSupported ? requestedSessionStatus : 'ALL';

    if (request != null) {
      criteria.profileId = parseId(request.profileId);
      criteria.noRole = request.roleId == 'NONE';
      criteria.roleId = criteria.noRole ? null : parseId(request.roleId);
    }
    return criteria;
  }

  /** Only accepts a cursor whose fingerprint matches the current filter/sort combination. */
  private UserAccessMonitorModels.Cursor resolveCursor(
    UserAccessMonitorRequest request,
    UserAccessMonitorModels.Criteria criteria
  ) {
    UserAccessMonitorModels.Cursor decoded = decodeCursor(
      request == null ? null : request.cursor
    );
    if (decoded == null)
      return null;
    return decoded.fingerprint == buildFingerprint(criteria) ? decoded : null;
  }

  private static String buildFingerprint(
    UserAccessMonitorModels.Criteria criteria
  ) {
    return String.join(
      new List<String>{
        String.valueOf(criteria.sortField),
        String.valueOf(criteria.sortDirection),
        String.valueOf(criteria.pageSize),
        String.valueOf(criteria.searchTerm),
        String.valueOf(criteria.userStatus),
        String.valueOf(criteria.sessionStatus),
        String.valueOf(criteria.profileId),
        String.valueOf(criteria.roleId),
        String.valueOf(criteria.noRole),
        String.valueOf(criteria.loginRecency)
      },
      '|'
    );
  }

  private static String encodeCursor(UserAccessMonitorModels.Cursor cursor) {
    if (cursor == null)
      return null;
    return EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(cursor)));
  }

  /** Malformed cursors are treated as "start from the first page", never as errors. */
  private static UserAccessMonitorModels.Cursor decodeCursor(
    String encodedCursor
  ) {
    if (String.isBlank(encodedCursor))
      return null;
    try {
      String cursorJson = EncodingUtil.base64Decode(encodedCursor).toString();
      return (UserAccessMonitorModels.Cursor) JSON.deserialize(
        cursorJson,
        UserAccessMonitorModels.Cursor.class
      );
    } catch (Exception malformedCursorException) {
      return null;
    }
  }

  private static Id parseId(String value) {
    if (String.isBlank(value))
      return null;
    try {
      return (Id) value;
    } catch (Exception invalidIdException) {
      return null;
    }
  }
}
