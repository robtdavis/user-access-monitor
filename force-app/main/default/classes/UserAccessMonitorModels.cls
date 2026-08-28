/**
 * Shared request, response, and internal data-transfer types for the User Access Monitor
 * feature. Selectors and the service depend only on these models, never on types nested
 * inside the controller, so dependencies point outward from persistence toward the boundary.
 */
public with sharing class UserAccessMonitorModels {
  /** Detects users with a currently active session, without exposing session identifiers. */
  public interface SessionProvider {
    Set<Id> getActiveUserIds();
    Boolean isSupported();
    String getWarning();
  }

  /** Decouples the Custom Permission check from the controller so it can be faked in tests. */
  public interface PermissionChecker {
    Boolean hasAccess();
  }

  public class Request {
    @AuraEnabled
    public String cursor;
    @AuraEnabled
    public Integer pageSize;
    @AuraEnabled
    public String searchTerm;
    @AuraEnabled
    public String userStatus;
    @AuraEnabled
    public String sessionStatus;
    @AuraEnabled
    public String profileId;
    @AuraEnabled
    public String roleId;
    @AuraEnabled
    public String loginRecency;
    @AuraEnabled
    public String sortField;
    @AuraEnabled
    public String sortDirection;
  }

  /** Normalized, validated form of Request. Only this type is passed into selectors. */
  public class Criteria {
    public Integer pageSize;
    public String searchTerm;
    public String userStatus;
    public String sessionStatus;
    public Id profileId;
    public Boolean noRole;
    public Id roleId;
    public String loginRecency;
    public String sortField;
    public String sortDirection;
    public Set<Id> activeSessionUserIds = new Set<Id>();
    public Cursor afterCursor;
  }

  /**
   * Opaque keyset pagination position. "bucket" is only meaningful for the default
   * (session-first) ordering: SESSION while still paging through active-session users,
   * OTHER once paging through the remaining users. It is null for explicit column sorts.
   */
  public class Cursor {
    public String bucket;
    public Boolean lastIsActive;
    public String lastLastName;
    public String lastFirstName;
    public String lastSortValue;
    public Id lastId;
    public String fingerprint;
  }

  public class UserPageResult {
    public List<User> records = new List<User>();
    public Boolean hasNextPage = false;
    public Cursor nextCursor;
  }

  public class ProfileOptionsResult {
    public List<Profile> records = new List<Profile>();
    public Boolean truncated = false;
  }

  public class RoleOptionsResult {
    public List<UserRole> records = new List<UserRole>();
    public Boolean truncated = false;
  }

  public class Response {
    @AuraEnabled
    public List<UserRow> rows = new List<UserRow>();
    @AuraEnabled
    public Integer totalMatchingUsers = 0;
    @AuraEnabled
    public Integer pageSize;
    @AuraEnabled
    public Boolean hasNextPage = false;
    @AuraEnabled
    public String nextCursor;
    @AuraEnabled
    public SummaryMetrics summary;
    @AuraEnabled
    public Boolean sessionDetectionSupported;
    @AuraEnabled
    public String warningMessage;
  }

  public class SummaryMetrics {
    @AuraEnabled
    public Integer totalMatchingUsers;
    @AuraEnabled
    public Integer activeUsers;
    @AuraEnabled
    public Integer inactiveUsers;
    @AuraEnabled
    public Integer activeSessionUsers;
    @AuraEnabled
    public Boolean activeSessionUsersAvailable;
    @AuraEnabled
    public Integer activeNeverLoggedIn;
    @AuraEnabled
    public Integer activeNoLoginIn90Days;
  }

  public class UserRow {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String firstName;
    @AuraEnabled
    public String lastName;
    @AuraEnabled
    public String username;
    @AuraEnabled
    public String email;
    @AuraEnabled
    public String department;
    @AuraEnabled
    public String company;
    @AuraEnabled
    public String userType;
    @AuraEnabled
    public Boolean isActive;
    @AuraEnabled
    public Datetime lastLoginDate;
    @AuraEnabled
    public Datetime createdDate;
    @AuraEnabled
    public String profileName;
    @AuraEnabled
    public String roleName;
    @AuraEnabled
    public Integer directPermissionSetCount = 0;
    @AuraEnabled
    public Integer permissionSetGroupCount = 0;
    @AuraEnabled
    public Boolean activeSessionDetected;
  }

  public class FilterOption {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String value;

    public FilterOption(String optionLabel, String optionValue) {
      label = optionLabel;
      value = optionValue;
    }
  }

  public class FilterOptionsResponse {
    @AuraEnabled
    public List<FilterOption> profiles = new List<FilterOption>();
    @AuraEnabled
    public List<FilterOption> roles = new List<FilterOption>();
    @AuraEnabled
    public Boolean profilesTruncated = false;
    @AuraEnabled
    public Boolean rolesTruncated = false;
  }
}
