/** Profile and Role filter options returned to the User Access Monitor LWC. */
public with sharing class UserAccessMonitorFilterOptionsResponse {
  @AuraEnabled
  public List<UserAccessMonitorFilterOption> profiles = new List<UserAccessMonitorFilterOption>();
  @AuraEnabled
  public List<UserAccessMonitorFilterOption> roles = new List<UserAccessMonitorFilterOption>();
  @AuraEnabled
  public Boolean profilesTruncated = false;
  @AuraEnabled
  public Boolean rolesTruncated = false;
}
