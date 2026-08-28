/** Read-only user row returned to the User Access Monitor LWC. */
public with sharing class UserAccessMonitorUserRow {
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
