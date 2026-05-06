const { invoke } = window.__TAURI__.core;
const { listen } = window.__TAURI__.event;
const { open } = window.__TAURI__.dialog;

// ── State ────────────────────────────────────────────────────────────────────
let connected = false;
let activityLog = [];

// ── DOM refs ─────────────────────────────────────────────────────────────────
const statusView = document.getElementById("status-view");
const settingsView = document.getElementById("settings-view");
const conflictsView = document.getElementById("conflicts-view");

const statusDot = document.getElementById("status-dot");
const statusText = document.getElementById("status-text");
const shipInfo = document.getElementById("ship-info");
const shipName = document.getElementById("ship-name");
const lastSync = document.getElementById("last-sync");
const conflictBar = document.getElementById("conflict-bar");
const conflictCount = document.getElementById("conflict-count");
const activityLogEl = document.getElementById("activity-log");

const shipUrlInput = document.getElementById("ship-url");
const accessCodeInput = document.getElementById("access-code");
const syncDirInput = document.getElementById("sync-dir");
const connectBtn = document.getElementById("connect-btn");
const disconnectBtn = document.getElementById("disconnect-btn");
const notebookSelect = document.getElementById("notebook-select");
const notebookList = document.getElementById("notebook-list");
const saveNotebooksBtn = document.getElementById("save-notebooks-btn");

// ── View switching ───────────────────────────────────────────────────────────
const viewIds = { [statusView?.id]: statusView, [settingsView?.id]: settingsView, [conflictsView?.id]: conflictsView };

function showView(view) {
  [statusView, settingsView, conflictsView].forEach(v => v.classList.remove("active"));
  view.classList.add("active");
  localStorage.setItem("lastView", view.id);
}

// Restore last view after first status poll
let viewRestored = false;
function restoreView() {
  if (viewRestored) return;
  viewRestored = true;
  if (!connected) return; // settings shown by updateConnectionUI
  const lastId = localStorage.getItem("lastView");
  if (lastId && viewIds[lastId]) {
    [statusView, settingsView, conflictsView].forEach(v => v.classList.remove("active"));
    viewIds[lastId].classList.add("active");
  }
}

document.getElementById("settings-btn").addEventListener("click", () => {
  showView(settingsView);
  // Show back button only when connected (so they can get back to status)
  document.getElementById("back-btn").classList.toggle("hidden", !connected);
});
document.getElementById("back-btn").addEventListener("click", () => showView(statusView));
document.getElementById("conflicts-back-btn").addEventListener("click", () => showView(statusView));
document.getElementById("show-conflicts-btn").addEventListener("click", () => showView(conflictsView));

// ── Settings: load/save ──────────────────────────────────────────────────────
async function loadConfig() {
  try {
    const config = await invoke("get_config");
    shipUrlInput.value = config.ship_url || "";
    accessCodeInput.value = config.access_code || "";
    syncDirInput.value = config.sync_dir || "";
  } catch (e) {
    console.error("Failed to load config:", e);
  }
}

async function saveConfig() {
  // Load existing config first so we don't clobber selected_notebooks
  let existing = {};
  try { existing = await invoke("get_config"); } catch {}
  const config = {
    ship_url: shipUrlInput.value,
    access_code: accessCodeInput.value,
    sync_dir: syncDirInput.value,
    selected_notebooks: existing.selected_notebooks || [],
    sync_on_launch: true,
  };
  await invoke("save_config", { config });
}

// ── Directory picker ─────────────────────────────────────────────────────────
document.getElementById("pick-dir-btn").addEventListener("click", async () => {
  const selected = await open({ directory: true, title: "Choose sync directory" });
  if (selected) {
    syncDirInput.value = selected;
  }
});

// ── Connect / Disconnect ─────────────────────────────────────────────────────
connectBtn.addEventListener("click", async () => {
  connectBtn.disabled = true;
  connectBtn.textContent = "Connecting...";
  try {
    await saveConfig();
    await invoke("connect");
    connected = true;
    updateConnectionUI();
    await loadNotebooks();
  } catch (e) {
    addActivity("Connection failed: " + e);
    connectBtn.disabled = false;
    connectBtn.textContent = "Connect";
  }
});

disconnectBtn.addEventListener("click", async () => {
  await invoke("disconnect");
  connected = false;
  updateConnectionUI();
  notebookSelect.classList.add("hidden");
  saveNotebooksBtn.classList.add("hidden");
});

document.getElementById("quit-btn").addEventListener("click", async () => {
  await invoke("quit_app");
});

let lastConnected = null;
function updateConnectionUI() {
  if (connected) {
    connectBtn.classList.add("hidden");
    disconnectBtn.classList.remove("hidden");
    statusDot.className = "dot connected";
    statusText.textContent = "Connected";
    shipInfo.classList.remove("hidden");
  } else {
    connectBtn.classList.remove("hidden");
    connectBtn.disabled = false;
    connectBtn.textContent = "Connect";
    disconnectBtn.classList.add("hidden");
    statusDot.className = "dot disconnected";
    statusText.textContent = "Disconnected";
    shipInfo.classList.add("hidden");
  }
  // Only auto-switch view on a connection-state transition,
  // otherwise the 5s poll yanks the user off whatever view they navigated to.
  if (lastConnected !== connected) {
    if (connected) {
      showView(statusView);
      // Backend already has the config + auth; populate the picker so it's
      // ready when the user opens settings (e.g. after auto-connect).
      loadNotebooks();
    } else {
      showView(settingsView);
      document.getElementById("back-btn").classList.add("hidden");
    }
    lastConnected = connected;
  }
}

// ── Notebooks ────────────────────────────────────────────────────────────────
async function loadNotebooks() {
  try {
    const [notebooks, config] = await Promise.all([
      invoke("get_notebooks"),
      invoke("get_config"),
    ]);
    const selected = new Set(config.selected_notebooks || []);
    notebookList.innerHTML = "";
    notebooks.forEach(nb => {
      const div = document.createElement("div");
      div.className = "notebook-item";
      const checked = selected.has(nb.flag) ? " checked" : "";
      div.innerHTML = `
        <input type="checkbox" value="${nb.flag}"${checked}>
        <span>${nb.title}</span>
        <span class="host">${nb.host}</span>
      `;
      notebookList.appendChild(div);
    });
    notebookSelect.classList.remove("hidden");
    saveNotebooksBtn.classList.remove("hidden");
  } catch (e) {
    console.error("Failed to load notebooks:", e);
  }
}

function getSelectedNotebooks() {
  return Array.from(notebookList.querySelectorAll("input:checked")).map(cb => cb.value);
}

saveNotebooksBtn.addEventListener("click", async () => {
  const flags = getSelectedNotebooks();
  saveNotebooksBtn.disabled = true;
  saveNotebooksBtn.textContent = "Syncing...";
  try {
    await invoke("select_notebooks", { flags });
    addActivity("Sync started for " + flags.length + " notebook(s)");
    showView(statusView);
  } catch (e) {
    addActivity("Sync failed: " + e);
  }
  saveNotebooksBtn.disabled = false;
  saveNotebooksBtn.textContent = "Start Sync";
});

// ── Status polling ───────────────────────────────────────────────────────────
async function pollStatus() {
  try {
    const status = await invoke("get_status");
    connected = status.connected;
    updateConnectionUI();
    restoreView();

    if (status.ship) shipName.textContent = status.ship;
    if (status.last_sync) {
      const d = new Date(status.last_sync * 1000);
      lastSync.textContent = "Last sync: " + d.toLocaleTimeString();
    }

    if (status.conflicts > 0) {
      conflictBar.classList.remove("hidden");
      conflictCount.textContent = status.conflicts;
    } else {
      conflictBar.classList.add("hidden");
    }
  } catch (e) {
    // ignore polling errors
  }
}

// ── Activity log ─────────────────────────────────────────────────────────────
function addActivity(msg) {
  const now = new Date();
  const time = now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  activityLog.unshift({ time, msg });
  if (activityLog.length > 20) activityLog.pop();
  renderActivity();
}

function renderActivity() {
  if (activityLog.length === 0) {
    activityLogEl.innerHTML = '<div class="empty-state">No sync activity yet</div>';
    return;
  }
  activityLogEl.innerHTML = activityLog
    .map(e => `<div class="entry"><span class="time">${e.time}</span>${e.msg}</div>`)
    .join("");
}

// ── Tauri event listeners ────────────────────────────────────────────────────
listen("sync-activity", (event) => {
  addActivity(event.payload);
});

listen("sync-status-changed", (_event) => {
  pollStatus();
});

listen("sync-conflict", (event) => {
  addActivity("Conflict: " + event.payload);
  pollStatus();
});

// ── Load activity from backend ───────────────────────────────────────────────
async function loadActivity() {
  try {
    const items = await invoke("get_activity");
    if (items.length > 0) {
      activityLog = items.map(msg => {
        const now = new Date();
        return { time: now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }), msg };
      }).reverse();
      renderActivity();
    }
  } catch {}
}

// ── Init ─────────────────────────────────────────────────────────────────────
loadConfig();
pollStatus();
loadActivity();
setInterval(() => { pollStatus(); loadActivity(); }, 5000);
