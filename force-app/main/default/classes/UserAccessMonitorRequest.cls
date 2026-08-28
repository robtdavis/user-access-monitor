/** Request sent by the User Access Monitor LWC. */
public with sharing class UserAccessMonitorRequest {
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
