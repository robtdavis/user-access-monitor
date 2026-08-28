/** Aggregate metrics for all users matching the current filters. */
public with sharing class UserAccessMonitorSummaryMetrics {
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
