import { LightningElement } from "lwc";
import getUsers from "@salesforce/apex/UserAccessMonitorController.getUsers";
import getFilterOptions from "@salesforce/apex/UserAccessMonitorController.getFilterOptions";

const SEARCH_DEBOUNCE_MS = 300;

const DEFAULT_REQUEST = {
  cursor: null,
  searchTerm: "",
  userStatus: "ALL",
  sessionStatus: "ALL",
  profileId: "",
  roleId: "",
  loginRecency: "ANY",
  sortField: "DEFAULT",
  sortDirection: "asc"
};

// The datatable's Status column must display its sort arrow using its own fieldName
// (statusText), but the server only recognizes the underlying field name (isActive).
const COLUMN_TO_SERVER_SORT_FIELD = {
  statusText: "isActive"
};
const SERVER_TO_COLUMN_SORT_FIELD = {
  isActive: "statusText"
};

export default class UserAccessMonitor extends LightningElement {
  rows = [];
  response;
  filterOptionsResponse;
  isLoading = true;
  errorMessage;
  isUnauthorized = false;
  filterOptionsErrorMessage;
  request = { ...DEFAULT_REQUEST };
  cursorHistory = [];
  searchTimer;
  usersRequestSequence = 0;
  optionsRequestSequence = 0;

  columns = [
    {
      label: "Session status",
      fieldName: "sessionStatusText",
      type: "text",
      cellAttributes: {
        iconName: { fieldName: "sessionIconName" },
        iconAlternativeText: { fieldName: "sessionStatusText" }
      },
      sortable: false
    },
    { label: "First Name", fieldName: "firstName", sortable: true },
    { label: "Last Name", fieldName: "lastName", sortable: true },
    { label: "Username", fieldName: "username", sortable: true },
    { label: "Email", fieldName: "email", sortable: true },
    { label: "Department", fieldName: "department", sortable: true },
    { label: "Company", fieldName: "company", sortable: true },
    { label: "User Type", fieldName: "userType", sortable: true },
    { label: "Status", fieldName: "statusText", sortable: true },
    {
      label: "Last Login",
      fieldName: "lastLoginDate",
      type: "date",
      typeAttributes: {
        year: "numeric",
        month: "short",
        day: "numeric",
        hour: "2-digit",
        minute: "2-digit"
      },
      sortable: true
    },
    {
      label: "Created",
      fieldName: "createdDate",
      type: "date",
      typeAttributes: { year: "numeric", month: "short", day: "numeric" },
      sortable: true
    },
    { label: "Profile", fieldName: "profileName", sortable: true },
    { label: "Role", fieldName: "roleName", sortable: true },
    {
      label: "Direct Permission Sets",
      fieldName: "directPermissionSetCount",
      type: "number",
      sortable: false
    },
    {
      label: "Permission Set Groups",
      fieldName: "permissionSetGroupCount",
      type: "number",
      sortable: false
    }
  ];

  connectedCallback() {
    this.loadFilterOptions();
    this.loadUsers();
  }

  async loadFilterOptions() {
    const sequence = ++this.optionsRequestSequence;
    try {
      const options = await getFilterOptions();
      if (sequence !== this.optionsRequestSequence) {
        return;
      }
      this.filterOptionsResponse = options;
      this.filterOptionsErrorMessage = undefined;
    } catch (error) {
      if (sequence === this.optionsRequestSequence) {
        this.filterOptionsErrorMessage = this.extractMessage(error);
      }
    }
  }

  async loadUsers() {
    const sequence = ++this.usersRequestSequence;
    this.isLoading = true;
    this.errorMessage = undefined;
    this.isUnauthorized = false;
    try {
      const response = await getUsers({ request: { ...this.request } });
      if (sequence !== this.usersRequestSequence) {
        return;
      }
      this.response = response;
      this.rows = this.mapRows(response.rows);
    } catch (error) {
      if (sequence === this.usersRequestSequence) {
        this.handleUsersError(error);
      }
    } finally {
      if (sequence === this.usersRequestSequence) {
        this.isLoading = false;
      }
    }
  }

  mapRows(rows) {
    return (rows || []).map((row) => ({
      ...row,
      sessionStatusText: row.activeSessionDetected
        ? "Active Session Detected"
        : "No Active Session Detected",
      sessionIconName: row.activeSessionDetected
        ? "utility:success"
        : "utility:close",
      statusText: row.isActive ? "Active" : "Inactive"
    }));
  }

  handleUsersError(error) {
    const message = this.extractMessage(error);
    this.isUnauthorized = message.toLowerCase().includes("not authorized");
    this.errorMessage = this.isUnauthorized ? undefined : message;
  }

  extractMessage(error) {
    return error?.body?.message || error?.message || "Please try again later.";
  }

  handleSearch(event) {
    this.applyRequestChange({ searchTerm: event.target.value });
    clearTimeout(this.searchTimer);
    // The timer is the debounce boundary required for server-side search.
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.searchTimer = setTimeout(() => {
      this.loadUsers();
    }, SEARCH_DEBOUNCE_MS);
  }

  handleFilterChange(event) {
    this.applyRequestChange({ [event.target.name]: event.detail.value });
    this.loadUsers();
  }

  handleSort(event) {
    const serverField =
      COLUMN_TO_SERVER_SORT_FIELD[event.detail.fieldName] ||
      event.detail.fieldName;
    this.applyRequestChange({
      sortField: serverField,
      sortDirection: event.detail.sortDirection
    });
    this.loadUsers();
  }

  handleRefresh() {
    this.applyRequestChange({});
    this.loadUsers();
    this.loadFilterOptions();
  }

  handleReset() {
    this.request = { ...DEFAULT_REQUEST };
    this.cursorHistory = [];
    this.loadUsers();
  }

  handleNextPage() {
    if (!this.hasNextPage) {
      return;
    }
    this.cursorHistory = [...this.cursorHistory, this.request.cursor || null];
    this.request = { ...this.request, cursor: this.response?.nextCursor };
    this.loadUsers();
  }

  handlePreviousPage() {
    if (!this.hasPreviousPage) {
      return;
    }
    const history = [...this.cursorHistory];
    const previousCursor = history.pop();
    this.cursorHistory = history;
    this.request = { ...this.request, cursor: previousCursor };
    this.loadUsers();
  }

  // Any change to search, filters, or sorting starts back at the first page.
  applyRequestChange(changes) {
    this.request = { ...this.request, ...changes, cursor: null };
    this.cursorHistory = [];
  }

  get statusOptions() {
    return [
      { label: "All users", value: "ALL" },
      { label: "Active users", value: "ACTIVE" },
      { label: "Inactive users", value: "INACTIVE" }
    ];
  }

  get sessionOptions() {
    return [
      { label: "All session statuses", value: "ALL" },
      { label: "Active session detected", value: "ACTIVE" },
      { label: "No active session detected", value: "INACTIVE" }
    ];
  }

  get loginOptions() {
    return [
      { label: "Any login date", value: "ANY" },
      { label: "Last 7 days", value: "DAYS_7" },
      { label: "Last 30 days", value: "DAYS_30" },
      { label: "Last 60 days", value: "DAYS_60" },
      { label: "Last 90 days", value: "DAYS_90" },
      { label: "More than 90 days", value: "MORE_THAN_90" },
      { label: "Never logged in", value: "NEVER" }
    ];
  }

  get profileOptions() {
    const profiles = this.filterOptionsResponse?.profiles || [];
    return [{ label: "All profiles", value: "" }, ...profiles];
  }

  get roleOptions() {
    const roles = this.filterOptionsResponse?.roles || [];
    return [
      { label: "All roles", value: "" },
      { label: "No role", value: "NONE" },
      ...roles
    ];
  }

  get metrics() {
    const summary = this.response?.summary || {};
    const sessionValue =
      summary.activeSessionUsersAvailable === false
        ? "Unavailable"
        : (summary.activeSessionUsers ?? 0);
    return [
      { label: "Total matching users", value: summary.totalMatchingUsers ?? 0 },
      { label: "Active users", value: summary.activeUsers ?? 0 },
      { label: "Inactive users", value: summary.inactiveUsers ?? 0 },
      { label: "Active sessions detected", value: sessionValue },
      {
        label: "Active, never logged in",
        value: summary.activeNeverLoggedIn ?? 0
      },
      {
        label: "Active, no login in 90 days",
        value: summary.activeNoLoginIn90Days ?? 0
      }
    ];
  }

  get totalMatchingUsers() {
    return this.response?.totalMatchingUsers || 0;
  }

  get hasNextPage() {
    return Boolean(this.response?.hasNextPage);
  }

  get hasPreviousPage() {
    return this.cursorHistory.length > 0;
  }

  get isNextDisabled() {
    return !this.hasNextPage;
  }

  get isPreviousDisabled() {
    return !this.hasPreviousPage;
  }

  get isSessionFilterDisabled() {
    return this.response ? !this.response.sessionDetectionSupported : false;
  }

  get filterOptionsNotice() {
    if (!this.filterOptionsResponse) {
      return undefined;
    }
    if (this.filterOptionsResponse.profilesTruncated) {
      return "Not all Profiles are shown in the dropdown. Use search to reach users by any Profile.";
    }
    if (this.filterOptionsResponse.rolesTruncated) {
      return "Not all Roles are shown in the dropdown. Use search to reach users by any Role.";
    }
    return undefined;
  }

  get warningMessage() {
    return this.response?.warningMessage;
  }

  get showTable() {
    return (
      !this.isLoading &&
      !this.hasError &&
      !this.isUnauthorized &&
      this.rows.length > 0
    );
  }

  get showEmpty() {
    return (
      !this.isLoading &&
      !this.hasError &&
      !this.isUnauthorized &&
      this.rows.length === 0
    );
  }

  get hasError() {
    return Boolean(this.errorMessage);
  }

  get hasFilterOptionsError() {
    return Boolean(this.filterOptionsErrorMessage);
  }

  get sortedByColumnField() {
    return (
      SERVER_TO_COLUMN_SORT_FIELD[this.request.sortField] ||
      this.request.sortField
    );
  }

  get sortDirection() {
    return this.request.sortDirection;
  }

  get searchTerm() {
    return this.request.searchTerm;
  }

  get userStatus() {
    return this.request.userStatus;
  }

  get sessionStatus() {
    return this.request.sessionStatus;
  }

  get profileId() {
    return this.request.profileId;
  }

  get roleId() {
    return this.request.roleId;
  }

  get loginRecency() {
    return this.request.loginRecency;
  }
}
