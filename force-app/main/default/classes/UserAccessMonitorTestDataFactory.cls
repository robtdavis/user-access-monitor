@IsTest
public class UserAccessMonitorTestDataFactory {
  private static Integer userCounter = 0;

  public static User buildUser(
    String firstName,
    String lastName,
    Boolean isActive
  ) {
    Profile standardProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    return buildUser(firstName, lastName, isActive, standardProfile.Id);
  }

  public static User buildUser(
    String firstName,
    String lastName,
    Boolean isActive,
    Id profileId
  ) {
    userCounter++;
    String uniqueToken =
      String.valueOf(Crypto.getRandomInteger()).right(6) + userCounter;
    return new User(
      FirstName = firstName,
      LastName = lastName,
      Alias = ('u' + uniqueToken).left(8),
      Email = 'uam' + uniqueToken + '@example.com',
      Username = 'uam' +
        uniqueToken +
        '@example.com.' +
        String.valueOf(Math.abs(Crypto.getRandomInteger())),
      ProfileId = profileId,
      IsActive = isActive,
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
  }

  public static Id standardProfileId() {
    return [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id;
  }

  public class FakeSessionProvider implements UserAccessMonitorModels.SessionProvider {
    private Set<Id> activeUserIds;
    private Boolean supported;
    private String warning;

    public FakeSessionProvider(Set<Id> activeUserIds) {
      this(activeUserIds, true, null);
    }

    public FakeSessionProvider(
      Set<Id> activeUserIds,
      Boolean supported,
      String warning
    ) {
      this.activeUserIds = activeUserIds;
      this.supported = supported;
      this.warning = warning;
    }

    public Set<Id> getActiveUserIds() {
      return activeUserIds;
    }

    public Boolean isSupported() {
      return supported;
    }

    public String getWarning() {
      return warning;
    }
  }

  public class FakePermissionChecker implements UserAccessMonitorModels.PermissionChecker {
    private Boolean access;

    public FakePermissionChecker(Boolean access) {
      this.access = access;
    }

    public Boolean hasAccess() {
      return access;
    }
  }
}
