/** Request sent by the User Access Monitor LWC. */
public with sharing class UserAccessMonitorRequest {
  @AuraEnabled
  public String cursor { get; set; }
  @AuraEnabled
  public Integer pageSize { get; set; }
  @AuraEnabled
  public String searchTerm { get; set; }
  @AuraEnabled
  public String userStatus { get; set; }
  @AuraEnabled
  public String sessionStatus { get; set; }
  @AuraEnabled
  public String profileId { get; set; }
  @AuraEnabled
  public String roleId { get; set; }
  @AuraEnabled
  public String loginRecency { get; set; }
  @AuraEnabled
  public String sortField { get; set; }
  @AuraEnabled
  public String sortDirection { get; set; }
}
