import { LightningElement } from 'lwc';
import getUsers from '@salesforce/apex/UserAccessMonitorController.getUsers';
import getFilterOptions from '@salesforce/apex/UserAccessMonitorController.getFilterOptions';

const DEFAULTS = { pageNumber: 1, pageSize: 100, searchTerm: '', userStatus: 'ALL', sessionStatus: 'ALL', profileId: '', roleId: '', loginRecency: 'ANY', sortField: 'DEFAULT', sortDirection: 'asc' };

export default class UserAccessMonitor extends LightningElement {
    rows = [];
    response;
    isLoading = true;
    errorMessage;
    isUnauthorized = false;
    request = { ...DEFAULTS };
    searchTimer;
    requestSequence = 0;
    profileOptions = [{ label: 'All profiles', value: '' }];
    roleOptions = [{ label: 'All roles', value: '' }, { label: 'No role', value: 'NONE' }];

    columns = [
        { label: 'Session status', fieldName: 'sessionStatusText', type: 'text', cellAttributes: { iconName: { fieldName: 'sessionIconName' }, iconAlternativeText: { fieldName: 'sessionStatusText' } }, sortable: false },
        { label: 'First Name', fieldName: 'firstName', sortable: true }, { label: 'Last Name', fieldName: 'lastName', sortable: true },
        { label: 'Username', fieldName: 'username', sortable: true }, { label: 'Email', fieldName: 'email', sortable: true },
        { label: 'Department', fieldName: 'department', sortable: true }, { label: 'Company', fieldName: 'company', sortable: true },
        { label: 'User Type', fieldName: 'userType', sortable: true }, { label: 'Status', fieldName: 'statusText', sortable: true },
        { label: 'Last Login', fieldName: 'lastLoginDate', type: 'date', typeAttributes: { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }, sortable: true },
        { label: 'Created', fieldName: 'createdDate', type: 'date', typeAttributes: { year: 'numeric', month: 'short', day: 'numeric' }, sortable: true },
        { label: 'Profile', fieldName: 'profileName', sortable: true }, { label: 'Role', fieldName: 'roleName', sortable: true },
        { label: 'Direct Permission Sets', fieldName: 'directPermissionSetCount', type: 'number', sortable: false }, { label: 'Permission Set Groups', fieldName: 'permissionSetGroupCount', type: 'number', sortable: false }
    ];

    connectedCallback() { this.loadOptions(); this.loadUsers(); }
    async loadOptions() { try { const options = await getFilterOptions(); this.profileOptions = this.profileOptions.concat(options.profiles || []); this.roleOptions = this.roleOptions.concat(options.roles || []); } catch (error) { this.setError(error); } }
    async loadUsers() {
        const sequence = ++this.requestSequence; this.isLoading = true; this.errorMessage = undefined; this.isUnauthorized = false;
        try {
            const response = await getUsers({ request: { ...this.request } });
            if (sequence !== this.requestSequence) return;
            this.response = response; this.rows = (response.rows || []).map((row) => ({ ...row, sessionStatusText: row.activeSessionDetected ? 'Active Session Detected' : 'No Active Session Detected', sessionIconName: row.activeSessionDetected ? 'utility:success' : 'utility:close', statusText: row.isActive ? 'Active' : 'Inactive' }));
        } catch (error) { if (sequence === this.requestSequence) this.setError(error); } finally { if (sequence === this.requestSequence) this.isLoading = false; }
    }
    setError(error) { const message = error?.body?.message || error?.message || 'Please try again later.'; this.isUnauthorized = message.toLowerCase().includes('not authorized'); this.errorMessage = this.isUnauthorized ? undefined : message; }
    handleSearch(event) {
        this.request.searchTerm = event.target.value;
        this.request.pageNumber = 1;
        clearTimeout(this.searchTimer);
        // The timer is the debounce boundary required for server-side search.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchTimer = setTimeout(() => this.loadUsers(), 300);
    }
    handleFilterChange(event) { this.request[event.target.name] = event.detail.value; this.request.pageNumber = 1; this.loadUsers(); }
    handleSort(event) { this.request.sortField = event.detail.fieldName; this.request.sortDirection = event.detail.sortDirection; this.request.pageNumber = 1; this.loadUsers(); }
    handleRefresh() { this.loadUsers(); }
    handleReset() { this.request = { ...DEFAULTS }; this.loadUsers(); }
    firstPage() { this.goToPage(1); } previousPage() { this.goToPage(this.currentPage - 1); } nextPage() { this.goToPage(this.currentPage + 1); } lastPage() { this.goToPage(this.totalPages); }
    goToPage(pageNumber) { if (pageNumber >= 1 && pageNumber <= this.totalPages) { this.request.pageNumber = pageNumber; this.loadUsers(); } }
    get statusOptions() { return [{ label: 'All users', value: 'ALL' }, { label: 'Active users', value: 'ACTIVE' }, { label: 'Inactive users', value: 'INACTIVE' }]; }
    get sessionOptions() { return [{ label: 'All session statuses', value: 'ALL' }, { label: 'Active session detected', value: 'ACTIVE' }, { label: 'No active session detected', value: 'INACTIVE' }]; }
    get loginOptions() { return [{ label: 'Any login date', value: 'ANY' }, { label: 'Last 7 days', value: 'DAYS_7' }, { label: 'Last 30 days', value: 'DAYS_30' }, { label: 'Last 60 days', value: 'DAYS_60' }, { label: 'Last 90 days', value: 'DAYS_90' }, { label: 'More than 90 days', value: 'MORE_THAN_90' }, { label: 'Never logged in', value: 'NEVER' }]; }
    get metrics() { const summary = this.response?.summary || {}; return [['Total matching users', summary.totalMatchingUsers], ['Active users', summary.activeUsers], ['Inactive users', summary.inactiveUsers], ['Active sessions detected', summary.activeSessionUsers], ['Active, never logged in', summary.activeNeverLoggedIn], ['Active, no login in 90 days', summary.activeNoLoginIn90Days]].map(([label, value]) => ({ label, value: value ?? 0 })); }
    get totalMatchingUsers() { return this.response?.totalMatchingUsers || 0; } get currentPage() { return this.response?.currentPage || 1; } get totalPages() { return this.response?.totalPages || 0; } get paginationWarning() { return this.response?.paginationWarning; } get warningMessage() { return this.response?.warningMessage; }
    get isFirstPage() { return this.currentPage <= 1 || this.totalPages === 0; } get isLastPage() { return this.currentPage >= this.totalPages || this.totalPages === 0 || Boolean(this.paginationWarning); } get showTable() { return !this.isLoading && !this.hasError && !this.isUnauthorized && this.rows.length > 0; } get showEmpty() { return !this.isLoading && !this.hasError && !this.isUnauthorized && this.rows.length === 0; } get hasError() { return Boolean(this.errorMessage); } get sortField() { return this.request.sortField; } get sortDirection() { return this.request.sortDirection; }
    get searchTerm() { return this.request.searchTerm; } get userStatus() { return this.request.userStatus; } get sessionStatus() { return this.request.sessionStatus; } get profileId() { return this.request.profileId; } get roleId() { return this.request.roleId; } get loginRecency() { return this.request.loginRecency; }
}
