/**
 * Detects "Active Session Detected" status from AuthSession.
 *
 * Signal used: an AuthSession row for the user with LastModifiedDate within the last
 * 30 minutes. AuthSession.LastModifiedDate advances on session creation and on periodic
 * platform session-activity updates, so a recent value is a reasonable proxy for "this
 * user's browser session was active recently" - not proof that the user is looking at
 * their screen right now.
 *
 * Required access: querying AuthSession requires "Manage Sessions" / View All Users type
 * setup-entity access, which is typically limited to system administrators. Only the
 * UsersId field is selected; no SessionId, session key, or IP address is read or returned.
 *
 * Known limitations:
 * - Stale or soon-to-expire sessions can still appear active within the 30-minute window.
 * - A user with multiple sessions (browser tabs, mobile, API/integration clients) is
 *   reported once, as a single boolean signal, not per-session.
 * - Integration and API-only users may hold long-lived sessions that do not reflect
 *   interactive presence.
 * - Org-wide session settings (timeouts, high-assurance policies) are not evaluated here.
 * For these reasons the UI must never label this "Online"; it is always presented as
 * "Active Session Detected".
 */
public with sharing class UserAccessMonitorAuthSessionProvider implements UserAccessMonitorModels.SessionProvider {
  private static final Integer SESSION_ACTIVITY_MINUTES = 30;

  private Boolean supported = true;
  private String warning;

  public Set<Id> getActiveUserIds() {
    Set<Id> userIds = new Set<Id>();
    try {
      Datetime activeSince = Datetime.now()
        .addMinutes(-SESSION_ACTIVITY_MINUTES);
      for (AuthSession sessionRecord : [
        SELECT UsersId
        FROM AuthSession
        WHERE LastModifiedDate >= :activeSince AND UsersId != NULL
      ]) {
        userIds.add(sessionRecord.UsersId);
      }
    } catch (Exception queryException) {
      supported = false;
      warning = 'Active session information is unavailable. Login recency is still shown.';
    }
    return userIds;
  }

  public Boolean isSupported() {
    return supported;
  }

  public String getWarning() {
    return warning;
  }
}
