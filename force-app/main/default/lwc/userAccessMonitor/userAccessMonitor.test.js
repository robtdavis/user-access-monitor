import { createElement } from 'lwc';
import UserAccessMonitor from 'c/userAccessMonitor';
import getUsers from '@salesforce/apex/UserAccessMonitorController.getUsers';
import getFilterOptions from '@salesforce/apex/UserAccessMonitorController.getFilterOptions';

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());
const response = { rows: [{ id: '1', firstName: 'Ada', lastName: 'Lovelace', isActive: true, activeSessionDetected: true }], totalMatchingUsers: 1, currentPage: 1, totalPages: 1, summary: { totalMatchingUsers: 1, activeUsers: 1, inactiveUsers: 0, activeSessionUsers: 1, activeNeverLoggedIn: 0, activeNoLoginIn90Days: 0 }, sessionDetectionSupported: true };

afterEach(() => { while (document.body.firstChild) document.body.removeChild(document.body.firstChild); jest.clearAllMocks(); });

test('loads users and options', async () => {
    getFilterOptions.mockResolvedValue({ profiles: [], roles: [] }); getUsers.mockResolvedValue(response);
    const element = createElement('c-user-access-monitor', { is: UserAccessMonitor }); document.body.appendChild(element); await flushPromises();
    expect(getUsers).toHaveBeenCalled(); expect(element.shadowRoot.querySelector('lightning-datatable').data[0].sessionStatusText).toBe('Active Session Detected');
});

test('shows empty state', async () => {
    getFilterOptions.mockResolvedValue({ profiles: [], roles: [] }); getUsers.mockResolvedValue({ ...response, rows: [], totalMatchingUsers: 0, totalPages: 0 });
    const element = createElement('c-user-access-monitor', { is: UserAccessMonitor }); document.body.appendChild(element); await flushPromises();
    expect(element.shadowRoot.textContent).toContain('No users match these filters');
});

test('prevents an older response from replacing newer data', async () => {
    jest.useFakeTimers(); getFilterOptions.mockResolvedValue({ profiles: [], roles: [] });
    let resolveFirst; const first = new Promise((resolve) => { resolveFirst = resolve; }); getUsers.mockReturnValueOnce(first).mockResolvedValueOnce(response);
    const element = createElement('c-user-access-monitor', { is: UserAccessMonitor }); document.body.appendChild(element); await flushPromises();
    const searchInput = element.shadowRoot.querySelector('lightning-input'); searchInput.value = 'new'; searchInput.dispatchEvent(new CustomEvent('change'));
    jest.advanceTimersByTime(300); await flushPromises(); resolveFirst({ ...response, rows: [{ id: 'old' }] }); await flushPromises();
    expect(element.shadowRoot.querySelector('lightning-datatable').data[0].id).toBe('1'); jest.useRealTimers();
});
