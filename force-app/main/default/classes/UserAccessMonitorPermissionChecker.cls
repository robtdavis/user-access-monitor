/** Default authorization check backed by the View_User_Access_Monitor Custom Permission. */
public with sharing class UserAccessMonitorPermissionChecker implements UserAccessMonitorModels.PermissionChecker {
  public Boolean hasAccess() {
    return FeatureManagement.checkPermission('View_User_Access_Monitor');
  }
}
