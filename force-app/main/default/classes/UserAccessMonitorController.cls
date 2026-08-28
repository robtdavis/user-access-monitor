/**
 * Aura entry point for the User Access Monitor. Enforces the View_User_Access_Monitor
 * Custom Permission before returning any data, then delegates entirely to
 * UserAccessMonitorService. Contains no SOQL, session-detection rules, or business logic.
 *
 * Sharing: "with sharing" is used here and throughout the feature's Apex classes.
 * UserAccessMonitorUserSelector and UserAccessMonitorPermissionSelector explicitly run
 * their queries with AccessLevel.SYSTEM_MODE, a deliberate, scoped exception to normal
 * object/field-level sharing enforcement for those queries only. It is required because
 * User, PermissionSetAssignment, and AuthSession are Setup objects: ordinary record-level
 * sharing rules do not apply to them the way they do to standard business data, and an
 * administrator authorized by the Custom Permission gate below needs a complete, consistent
 * view of user access regardless of their own record visibility. The Custom Permission check
 * below - not sharing or field-level security - is what restricts this data to authorized
 * administrators.
 */
public with sharing class UserAccessMonitorController {
  @TestVisible
  private static UserAccessMonitorModels.PermissionChecker permissionChecker = new UserAccessMonitorPermissionChecker();
  @TestVisible
  private static UserAccessMonitorModels.SessionProvider sessionProvider = new UserAccessMonitorAuthSessionProvider();

  @AuraEnabled(cacheable=true)
  public static UserAccessMonitorModels.Response getUsers(
    UserAccessMonitorModels.Request request
  ) {
    authorize();
    return new UserAccessMonitorService(sessionProvider).getUsers(request);
  }

  @AuraEnabled(cacheable=true)
  public static UserAccessMonitorModels.FilterOptionsResponse getFilterOptions() {
    authorize();
    return new UserAccessMonitorService(sessionProvider).getFilterOptions();
  }

  private static void authorize() {
    if (!permissionChecker.hasAccess()) {
      // AuraHandledException.getMessage() returns a generic "Script-thrown exception"
      // unless setMessage() is called explicitly, even though the constructor argument
      // is what the client actually receives in error.body.message.
      AuraHandledException authorizationException = new AuraHandledException(
        'You are not authorized to view User Access Monitor.'
      );
      authorizationException.setMessage(
        'You are not authorized to view User Access Monitor.'
      );
      throw authorizationException;
    }
  }
}
      );
    }
  }
}
