/**
 * Internal data-transfer types for the User Access Monitor feature. Types that cross the
 * Lightning/Apex boundary are top-level classes because Lightning does not support Apex
 * inner classes as AuraEnabled parameters or return values.
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

  /** Normalized form of UserAccessMonitorRequest. Only this type is passed into selectors. */
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
}
