/**
 * Retrieves Permission Set and Permission Set Group assignment counts for a batch of Users
 * in a single aggregate query, so no SOQL runs inside a per-user loop. PermissionSetAssignment
 * rows where PermissionSetGroupId is null are direct assignments; rows with a group Id are
 * counted as Permission Set Group membership. Profile-owned Permission Sets are excluded
 * because Salesforce represents a user's Profile access as a PermissionSetAssignment even
 * though an administrator did not directly assign that Permission Set.
 */
public with sharing class UserAccessMonitorPermissionSelector {
  public Counts findCounts(List<User> users) {
    Counts counts = new Counts();
    if (users.isEmpty())
      return counts;
    Set<Id> userIds = new Map<Id, User>(users).keySet();
    for (AggregateResult aggregateResult : [
      SELECT
        AssigneeId assigneeId,
        PermissionSetGroupId groupId,
        COUNT(Id) assignmentCount
      FROM PermissionSetAssignment
      WHERE
        AssigneeId IN :userIds
        AND (PermissionSetGroupId != NULL
        OR PermissionSet.IsOwnedByProfile = FALSE)
      GROUP BY AssigneeId, PermissionSetGroupId
    ]) {
      Id assigneeId = (Id) aggregateResult.get('assigneeId');
      Integer assignmentCount = (Integer) aggregateResult.get(
        'assignmentCount'
      );
      if (aggregateResult.get('groupId') == null) {
        counts.directCounts.put(assigneeId, assignmentCount);
      } else {
        counts.groupCounts.put(assigneeId, assignmentCount);
      }
    }
    return counts;
  }

  public class Counts {
    public Map<Id, Integer> directCounts = new Map<Id, Integer>();
    public Map<Id, Integer> groupCounts = new Map<Id, Integer>();
  }
}
