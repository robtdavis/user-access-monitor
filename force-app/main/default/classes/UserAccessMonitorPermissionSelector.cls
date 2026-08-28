/**
 * Retrieves Permission Set and Permission Set Group assignment counts for a batch of Users
 * in a single aggregate query, so no SOQL runs inside a per-user loop. PermissionSetAssignment
 * rows where PermissionSetGroupId is null are direct assignments; rows with a group Id are
 * counted as Permission Set Group membership. This avoids double-counting the individual
 * Permission Sets that a group grants, since those grants do not appear as separate
 * PermissionSetAssignment rows with a null group Id.
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
      WHERE AssigneeId IN :userIds
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
