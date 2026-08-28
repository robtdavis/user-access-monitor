/** Response returned to the User Access Monitor LWC. */
public with sharing class UserAccessMonitorResponse {
  @AuraEnabled
  public List<UserAccessMonitorUserRow> rows = new List<UserAccessMonitorUserRow>();
  @AuraEnabled
  public Integer totalMatchingUsers = 0;
  @AuraEnabled
  public Integer pageSize;
  @AuraEnabled
  public Boolean hasNextPage = false;
  @AuraEnabled
  public String nextCursor;
  @AuraEnabled
  public UserAccessMonitorSummaryMetrics summary;
  @AuraEnabled
  public Boolean sessionDetectionSupported;
  @AuraEnabled
  public String warningMessage;
}
