/** Label/value option used by a User Access Monitor filter. */
public with sharing class UserAccessMonitorFilterOption {
  @AuraEnabled
  public String label;
  @AuraEnabled
  public String value;

  public UserAccessMonitorFilterOption(String optionLabel, String optionValue) {
    label = optionLabel;
    value = optionValue;
  }
}
