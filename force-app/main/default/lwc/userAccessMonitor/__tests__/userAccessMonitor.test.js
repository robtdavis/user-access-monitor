import { createElement } from "lwc";
import UserAccessMonitor from "c/userAccessMonitor";
import getUsers from "@salesforce/apex/UserAccessMonitorController.getUsers";
import getFilterOptions from "@salesforce/apex/UserAccessMonitorController.getFilterOptions";

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

function buildResponse(overrides = {}) {
  return {
    rows: [
      {
        id: "1",
        firstName: "Ada",
        lastName: "Lovelace",
        isActive: true,
        activeSessionDetected: true
      }
    ],
    totalMatchingUsers: 1,
    pageSize: 10,
    hasNextPage: false,
    nextCursor: null,
    summary: {
      totalMatchingUsers: 1,
      activeUsers: 1,
      inactiveUsers: 0,
      activeSessionUsers: 1,
      activeSessionUsersAvailable: true,
      activeNeverLoggedIn: 0,
      activeNoLoginIn90Days: 0
    },
    sessionDetectionSupported: true,
    warningMessage: null,
    ...overrides
  };
}

function createUserAccessMonitor(pageSize) {
  const element = createElement("c-user-access-monitor", {
    is: UserAccessMonitor
  });
  if (pageSize !== undefined) {
    element.pageSize = pageSize;
  }
  document.body.appendChild(element);
  return element;
}

function findComboboxByName(element, name) {
  return [...element.shadowRoot.querySelectorAll("lightning-combobox")].find(
    (combobox) => combobox.name === name
  );
}

function findButtonByLabel(element, label) {
  return [...element.shadowRoot.querySelectorAll("lightning-button")].find(
    (button) => button.label === label
  );
}

async function createAndSettle(
  usersResponse,
  optionsResponse = {
    profiles: [],
    roles: [],
    profilesTruncated: false,
    rolesTruncated: false
  },
  pageSize
) {
  getFilterOptions.mockResolvedValue(optionsResponse);
  getUsers.mockResolvedValue(usersResponse);
  const element = createUserAccessMonitor(pageSize);
  await flushPromises();
  return element;
}

afterEach(() => {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
  jest.clearAllMocks();
  jest.useRealTimers();
});

describe("c-user-access-monitor loading and states", () => {
  it("loads users successfully and renders them in the table", async () => {
    const element = await createAndSettle(buildResponse());

    expect(getUsers).toHaveBeenCalledTimes(1);
    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable.data).toHaveLength(1);
    expect(datatable.data[0].sessionStatusText).toBe("Active Session Detected");
    expect(datatable.data[0].sessionStatusClass).toBe(
      "slds-text-color_success"
    );
    expect(datatable.data[0].userUrl).toBe("/lightning/r/User/1/view");
    expect(datatable.data[0].statusText).toBe("Active");
    expect(datatable.columns.every((column) => column.wrapText)).toBe(true);
    const usernameColumn = datatable.columns.find(
      (column) => column.label === "Username"
    );
    expect(usernameColumn.type).toBe("url");
    expect(usernameColumn.typeAttributes.target).toBe("_self");
  });

  it("shows a loading spinner while the request is in flight", async () => {
    getFilterOptions.mockResolvedValue({ profiles: [], roles: [] });
    let resolveUsers;
    getUsers.mockReturnValue(
      new Promise((resolve) => {
        resolveUsers = resolve;
      })
    );

    const element = createUserAccessMonitor();
    await flushPromises();

    expect(
      element.shadowRoot.querySelector("lightning-spinner")
    ).not.toBeNull();

    resolveUsers(buildResponse());
    await flushPromises();
    expect(element.shadowRoot.querySelector("lightning-spinner")).toBeNull();
  });

  it("shows an empty state when no users match the filters", async () => {
    const element = await createAndSettle(
      buildResponse({ rows: [], totalMatchingUsers: 0 })
    );

    expect(element.shadowRoot.textContent).toContain(
      "No users match these filters"
    );
  });

  it("shows a general error state on an unexpected failure", async () => {
    getFilterOptions.mockResolvedValue({ profiles: [], roles: [] });
    getUsers.mockRejectedValue(new Error("Something went wrong"));

    const element = createUserAccessMonitor();
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("We couldn't load users");
  });

  it("shows an unauthorized state when the server rejects for lack of permission", async () => {
    getFilterOptions.mockResolvedValue({ profiles: [], roles: [] });
    getUsers.mockRejectedValue({
      body: { message: "You are not authorized to view User Access Monitor." }
    });

    const element = createUserAccessMonitor();
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("Access not authorized");
  });

  it("shows a filter-options error without clobbering a successful table load", async () => {
    getFilterOptions.mockRejectedValue(new Error("Options failed"));
    getUsers.mockResolvedValue(buildResponse());

    const element = createUserAccessMonitor();
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(
      "Profile and Role filter options could not be loaded"
    );
    expect(
      element.shadowRoot.querySelector("lightning-datatable").data
    ).toHaveLength(1);
  });
});

describe("c-user-access-monitor search behavior", () => {
  it("debounces search input and issues a single request after the delay", async () => {
    jest.useFakeTimers();
    const element = await createAndSettle(buildResponse());
    getUsers.mockClear();

    const searchInput = element.shadowRoot.querySelector("lightning-input");
    searchInput.value = "a";
    searchInput.dispatchEvent(new CustomEvent("change"));
    searchInput.value = "ad";
    searchInput.dispatchEvent(new CustomEvent("change"));
    searchInput.value = "ada";
    searchInput.dispatchEvent(new CustomEvent("change"));

    jest.advanceTimersByTime(299);
    await flushPromises();
    expect(getUsers).not.toHaveBeenCalled();

    jest.advanceTimersByTime(1);
    await flushPromises();
    expect(getUsers).toHaveBeenCalledTimes(1);
    expect(getUsers.mock.calls[0][0].request.searchTerm).toBe("ada");
  });

  it("prevents a stale response from replacing a newer one", async () => {
    jest.useFakeTimers();
    const element = await createAndSettle(buildResponse());

    let resolveFirst;
    const firstRequest = new Promise((resolve) => {
      resolveFirst = resolve;
    });
    getUsers.mockReturnValueOnce(firstRequest).mockResolvedValueOnce(
      buildResponse({
        rows: [
          { id: "2", firstName: "Grace", lastName: "Hopper", isActive: true }
        ]
      })
    );

    const searchInput = element.shadowRoot.querySelector("lightning-input");
    searchInput.value = "first search";
    searchInput.dispatchEvent(new CustomEvent("change"));
    jest.advanceTimersByTime(300);
    await flushPromises();

    searchInput.value = "second search";
    searchInput.dispatchEvent(new CustomEvent("change"));
    jest.advanceTimersByTime(300);
    await flushPromises();

    resolveFirst(
      buildResponse({
        rows: [
          { id: "stale", firstName: "Stale", lastName: "Row", isActive: true }
        ]
      })
    );
    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable.data[0].id).toBe("2");
  });
});

describe("c-user-access-monitor filters", () => {
  it("sends the selected user status filter to the server", async () => {
    const element = await createAndSettle(buildResponse());
    getUsers.mockClear();

    const combobox = findComboboxByName(element, "userStatus");
    combobox.dispatchEvent(
      new CustomEvent("change", { detail: { value: "ACTIVE" } })
    );
    await flushPromises();

    expect(getUsers.mock.calls[0][0].request.userStatus).toBe("ACTIVE");
  });

  it("sends the selected session status filter to the server", async () => {
    const element = await createAndSettle(buildResponse());
    getUsers.mockClear();

    const combobox = findComboboxByName(element, "sessionStatus");
    combobox.dispatchEvent(
      new CustomEvent("change", { detail: { value: "ACTIVE" } })
    );
    await flushPromises();

    expect(getUsers.mock.calls[0][0].request.sessionStatus).toBe("ACTIVE");
  });

  it("disables the session status filter when session detection is unsupported", async () => {
    const element = await createAndSettle(
      buildResponse({
        sessionDetectionSupported: false,
        warningMessage: "unavailable"
      })
    );

    const combobox = findComboboxByName(element, "sessionStatus");
    expect(combobox.disabled).toBe(true);
    expect(element.shadowRoot.textContent).toContain("unavailable");
  });

  it("does not disable the session status filter when session detection is supported", async () => {
    const element = await createAndSettle(
      buildResponse({ sessionDetectionSupported: true })
    );

    const combobox = findComboboxByName(element, "sessionStatus");
    expect(combobox.disabled).toBe(false);
  });

  it("sends the selected profile filter to the server", async () => {
    const element = await createAndSettle(buildResponse());
    getUsers.mockClear();

    const combobox = findComboboxByName(element, "profileId");
    combobox.dispatchEvent(
      new CustomEvent("change", { detail: { value: "00e000000000001" } })
    );
    await flushPromises();

    expect(getUsers.mock.calls[0][0].request.profileId).toBe("00e000000000001");
  });

  it("sends the no-role value when the Role filter is set to No role", async () => {
    const element = await createAndSettle(buildResponse());
    getUsers.mockClear();

    const combobox = findComboboxByName(element, "roleId");
    combobox.dispatchEvent(
      new CustomEvent("change", { detail: { value: "NONE" } })
    );
    await flushPromises();

    expect(getUsers.mock.calls[0][0].request.roleId).toBe("NONE");
  });

  it("sends the selected login recency filter to the server", async () => {
    const element = await createAndSettle(buildResponse());
    getUsers.mockClear();

    const combobox = findComboboxByName(element, "loginRecency");
    combobox.dispatchEvent(
      new CustomEvent("change", { detail: { value: "DAYS_30" } })
    );
    await flushPromises();

    expect(getUsers.mock.calls[0][0].request.loginRecency).toBe("DAYS_30");
  });
});

describe("c-user-access-monitor sorting", () => {
  it("maps the Status column sort to the server-recognized isActive field", async () => {
    const element = await createAndSettle(buildResponse());
    getUsers.mockClear();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    datatable.dispatchEvent(
      new CustomEvent("sort", {
        detail: { fieldName: "statusText", sortDirection: "desc" }
      })
    );
    await flushPromises();

    expect(getUsers.mock.calls[0][0].request.sortField).toBe("isActive");
    expect(getUsers.mock.calls[0][0].request.sortDirection).toBe("desc");
  });

  it("sorts by other columns using their own field name", async () => {
    const element = await createAndSettle(buildResponse());
    getUsers.mockClear();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    datatable.dispatchEvent(
      new CustomEvent("sort", {
        detail: { fieldName: "lastName", sortDirection: "asc" }
      })
    );
    await flushPromises();

    expect(getUsers.mock.calls[0][0].request.sortField).toBe("lastName");
  });

  it("maps the linked Username column to the server username field", async () => {
    const element = await createAndSettle(buildResponse());
    getUsers.mockClear();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    datatable.dispatchEvent(
      new CustomEvent("sort", {
        detail: { fieldName: "userUrl", sortDirection: "asc" }
      })
    );
    await flushPromises();

    expect(getUsers.mock.calls[0][0].request.sortField).toBe("username");
    expect(
      element.shadowRoot.querySelector("lightning-datatable").sortedBy
    ).toBe("userUrl");
  });
});

describe("c-user-access-monitor pagination", () => {
  it("uses the App Builder page size when it is allowlisted", async () => {
    const element = await createAndSettle(
      buildResponse({ pageSize: 50 }),
      undefined,
      "50"
    );

    expect(getUsers.mock.calls[0][0].request.pageSize).toBe(50);
    expect(findComboboxByName(element, "pageSize").value).toBe("50");
  });

  it("defaults an unsupported App Builder page size to ten", async () => {
    await createAndSettle(buildResponse(), undefined, "37");

    expect(getUsers.mock.calls[0][0].request.pageSize).toBe(10);
  });

  it("shows a page-size dropdown and reloads the first page when changed", async () => {
    const element = await createAndSettle(
      buildResponse({
        pageSize: 10,
        hasNextPage: true,
        nextCursor: "cursor-1"
      })
    );
    getUsers.mockClear();
    getUsers.mockResolvedValue(buildResponse({ pageSize: 50 }));

    const pageSizeCombobox = findComboboxByName(element, "pageSize");
    expect(pageSizeCombobox).not.toBeUndefined();
    expect(pageSizeCombobox.value).toBe("10");
    expect(pageSizeCombobox.options.map((option) => option.value)).toEqual([
      "10",
      "50",
      "100",
      "200"
    ]);

    pageSizeCombobox.dispatchEvent(
      new CustomEvent("change", { detail: { value: "50" } })
    );
    await flushPromises();

    expect(getUsers.mock.calls[0][0].request.pageSize).toBe(50);
    expect(getUsers.mock.calls[0][0].request.cursor).toBe(null);
  });

  it("requests the next page using the returned cursor and can navigate back", async () => {
    const element = await createAndSettle(
      buildResponse({ hasNextPage: true, nextCursor: "cursor-1" })
    );
    getUsers.mockClear();
    getUsers.mockResolvedValue(
      buildResponse({ hasNextPage: false, nextCursor: null })
    );

    const nextButton = findButtonByLabel(element, "Next");
    nextButton.click();
    await flushPromises();

    expect(getUsers.mock.calls[0][0].request.cursor).toBe("cursor-1");

    getUsers.mockClear();
    getUsers.mockResolvedValue(
      buildResponse({ hasNextPage: true, nextCursor: "cursor-1" })
    );
    const previousButton = findButtonByLabel(element, "Previous");
    previousButton.click();
    await flushPromises();

    expect(getUsers.mock.calls[0][0].request.cursor).toBe(null);
  });
});

describe("c-user-access-monitor refresh and reset", () => {
  it("refresh reloads both users and filter options", async () => {
    const element = await createAndSettle(buildResponse());
    getUsers.mockClear();
    getFilterOptions.mockClear();

    const refreshButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button-icon")
    ].find((button) => button.iconName === "utility:refresh");
    refreshButton.click();
    await flushPromises();

    expect(getUsers).toHaveBeenCalledTimes(1);
    expect(getFilterOptions).toHaveBeenCalledTimes(1);
  });

  it("reset restores the default filters and reloads", async () => {
    const element = await createAndSettle(buildResponse());

    const combobox = findComboboxByName(element, "userStatus");
    combobox.dispatchEvent(
      new CustomEvent("change", { detail: { value: "ACTIVE" } })
    );
    await flushPromises();
    getUsers.mockClear();

    const resetButton = findButtonByLabel(element, "Reset Filters");
    resetButton.click();
    await flushPromises();

    expect(getUsers.mock.calls[0][0].request.userStatus).toBe("ALL");
  });
});

describe("c-user-access-monitor summary metrics", () => {
  it("renders the summary metric values from the response", async () => {
    const element = await createAndSettle(buildResponse());

    expect(element.shadowRoot.textContent).toContain("Total matching users");
    expect(element.shadowRoot.textContent).toContain(
      "Active sessions detected"
    );
  });

  it("shows Unavailable for the active session metric when detection is unsupported", async () => {
    const element = await createAndSettle(
      buildResponse({
        sessionDetectionSupported: false,
        warningMessage: "Active session information is unavailable.",
        summary: {
          totalMatchingUsers: 1,
          activeUsers: 1,
          inactiveUsers: 0,
          activeSessionUsers: null,
          activeSessionUsersAvailable: false,
          activeNeverLoggedIn: 0,
          activeNoLoginIn90Days: 0
        }
      })
    );

    expect(element.shadowRoot.textContent).toContain("Unavailable");
  });
});
