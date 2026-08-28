# User Access Monitor

User Access Monitor is a read-only Salesforce Lightning Web Component for administrators who need a concise operational view of users, access assignments, and recent login activity.

## Features

- Search users by name, username, email, department, company, Profile, or Role
- Filter by active status, detected session status, Profile, Role, and login recency
- Display Profile, Role, direct Permission Set count, and Permission Set Group count
- Highlight active users who have never logged in or have not logged in during the last 90 days
- Sort supported columns across the complete filtered result set
- Configure 10, 50, 100, or 200 rows per page in Lightning App Builder
- Navigate large result sets using cursor-based pagination without the 2,000-row SOQL `OFFSET` limit
- Restrict access with the `View_User_Access_Monitor` Custom Permission
- Fall back gracefully when session information is unavailable

The component is strictly read-only. It cannot activate, deactivate, freeze, edit, or delete users.

## Architecture

| Class                                  | Responsibility                                                                           |
| -------------------------------------- | ---------------------------------------------------------------------------------------- |
| `UserAccessMonitorController`          | Lightning entry point and authorization gate                                             |
| `UserAccessMonitorService`             | Request normalization, orchestration, metrics, pagination cursors, and response assembly |
| `UserAccessMonitorUserSelector`        | User, Profile, Role, count, filtering, sorting, and keyset queries                       |
| `UserAccessMonitorPermissionSelector`  | Direct Permission Set and Permission Set Group aggregate counts                          |
| `UserAccessMonitorAuthSessionProvider` | Best-effort detection of recently active sessions                                        |
| `UserAccessMonitorPermissionChecker`   | Custom Permission evaluation                                                             |
| `UserAccessMonitorModels`              | Internal interfaces, criteria, cursors, and selector result types                        |
| Top-level request and response DTOs    | Supported Lightning/Apex data boundary                                                   |

All user-supplied filter values are bound with `Database.queryWithBinds`. Sort fields and directions are allowlisted before they are added to dynamic SOQL.

## Security

Access requires both Apex class access to `UserAccessMonitorController` and the `View_User_Access_Monitor` Custom Permission. The included `User_Access_Monitor_Admin` Permission Set grants both requirements.

The feature intentionally queries administrative setup data in system mode after the Custom Permission check. Only fields needed by the component are selected. Session identifiers, tokens, IP addresses, and authentication secrets are never queried or returned.

## Session detection

The green indicator means **Active Session Detected**, not “online.”

The provider looks for an `AuthSession` record whose `LastModifiedDate` is within the preceding 30 minutes. This is a recent-activity signal, not proof that a person is currently looking at Salesforce. Stale sessions, mobile sessions, API clients, integrations, multiple sessions, and organization timeout policies can affect the result.

If the running user cannot query `AuthSession`, the component continues displaying users and login-recency information, shows a warning, displays the session metric as unavailable, and disables session-status filtering.

## Pagination

The component displays 10 users per page by default. A page administrator can select 10, 50, 100, or 200 rows using the **Rows Per Page** design property in Lightning App Builder. The server independently allowlists those values and defaults invalid input to 10.

Pagination uses opaque cursors. Previous and Next navigation replace numbered pages and Last Page navigation because exact page jumping is not compatible with scalable keyset pagination.

The default order is:

1. Users with an active session detected
2. Active users without a detected session
3. Inactive users
4. Last Name
5. First Name
6. User ID as a deterministic tie-breaker

Session-first ordering uses two query buckets because session status is not a field on `User` and cannot be placed directly in a User SOQL `ORDER BY` clause.

## Installation

Deploy the complete source directory:

```bash
sf project deploy start --source-dir force-app/main/default --target-org YOUR_ORG_ALIAS
```

Or deploy using the manifest:

```bash
sf project deploy start --manifest manifest/package.xml --target-org YOUR_ORG_ALIAS
```

Assign the included Permission Set:

```bash
sf org assign permset --name User_Access_Monitor_Admin --target-org YOUR_ORG_ALIAS
```

After deployment, open Lightning App Builder and add **User Access Monitor** to an App Page, Home Page, or Record Page. Activate the page for the intended administrators.

## Development

```bash
npm ci
npm run prettier:verify
npm run lint
npm run test:unit
```

Run Apex tests after authenticating a Salesforce org:

```bash
sf apex run test --class-names UserAccessMonitorControllerTest,UserAccessMonitorServiceTest,UserAccessMonitorUserSelectorTest,UserAccessMonitorPermissionSelectorTest --result-format human --wait 20 --target-org YOUR_ORG_ALIAS
```

## Manual verification

- Confirm a user without the Permission Set receives no data
- Confirm an assigned administrator can load the component
- Search by full name, username, email, Profile, and Role
- Exercise every filter and sortable column
- Verify Previous and Next navigation with more than 100 matching users
- Confirm Reset Filters returns to the first page
- Confirm Refresh requests current users and filter options
- Confirm users without Roles or login dates render correctly
- Confirm the component remains usable when `AuthSession` cannot be queried
- Verify the layout at desktop, tablet, and narrow viewport widths

## Known limitations

- Session detection is an approximation based on recent `AuthSession` activity.
- Profile and Role dropdowns return up to 2,000 options. A notice appears if either list is truncated; text search can still find users by Profile or Role name.
- Cursor-based pagination does not provide page numbers or direct Last Page navigation.


## License
## MIT License

Copyright (c) 2026 Robert Davis

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Unlocked Packages URL

Sandbox : https://test.salesforce.com/packaging/installPackage.apexp?p0=04tg8000000I7sfAAC

Production : https://login.salesforce.com/packaging/installPackage.apexp?p0=04tg8000000I7sfAAC

Always test in a Sandbox prior to installation in Production.