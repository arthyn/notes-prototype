^-  @t
'''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Notes</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  :root {
    --bg: #0f0f0f;
    --surface: #1a1a1a;
    --surface2: #222;
    --border: #2e2e2e;
    --text: #e8e8e8;
    --text-muted: #666;
    --accent: #7c6af7;
    --accent-hover: #9080ff;
    --danger: #e05c5c;
    --success: #4caf82;
    --font: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    --mono: "JetBrains Mono", "Fira Code", "Cascadia Code", monospace;
  }

  body {
    font-family: var(--font);
    background: var(--bg);
    color: var(--text);
    height: 100vh;
    height: 100dvh;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    position: fixed;
    inset: 0;
  }

  /* ── header ── */
  header {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 16px;
    border-bottom: 1px solid var(--border);
    background: var(--surface);
    flex-shrink: 0;
  }
  header h1 { font-size: 15px; font-weight: 600; letter-spacing: -0.3px; }
  #ship-label { font-size: 12px; color: var(--text-muted); margin-left: auto; }
  #status-dot {
    width: 8px; height: 8px; border-radius: 50%;
    background: var(--text-muted); flex-shrink: 0;
    transition: background 0.3s;
  }
  #status-dot.connected { background: var(--success); }
  #status-dot.error { background: var(--danger); }

  /* ── layout ── */
  .layout {
    display: flex;
    flex: 1;
    overflow: hidden;
  }

  /* ── sidebar ── */
  .sidebar {
    width: 220px;
    flex-shrink: 0;
    border-right: 1px solid var(--border);
    display: flex;
    flex-direction: column;
    background: var(--surface);
    overflow: hidden;
  }
  .sidebar-section {
    height: 41px;
    padding: 0 8px;
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    color: var(--text-muted);
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .sidebar-list { flex: 1; overflow-y: auto; padding-bottom: 8px; min-height: 0; }
  .nb-item {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 4px 6px;
    padding: 6px 10px;
    cursor: pointer;
    border-radius: 4px;
    margin: 1px 4px;
    font-size: 13px;
    transition: background 0.1s;
    user-select: none;
  }
  .nb-item:hover { background: var(--surface2); }
  .nb-item.active { background: var(--accent); color: #fff; }
  .nb-item .nb-icon { flex-shrink: 0; display: flex; align-items: center; }
  .nb-item .nb-name { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .nb-item .nb-flag {
    width: 100%;
    font-size: 10px;
    color: var(--text-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    padding-left: 22px;
  }
  .nb-item .nb-flag:hover { text-decoration: underline; }
  .nb-item.active .nb-flag { color: rgba(255,255,255,0.6); }

  /* ── sidebar bottom actions ── */
  .sidebar-actions {
    border-top: 1px solid var(--border);
    padding: 4px;
    flex-shrink: 0;
    background: var(--surface);
  }
  .sidebar-action {
    display: flex; align-items: center; gap: 8px;
    width: 100%;
    background: none; border: none; cursor: pointer;
    color: var(--text-muted);
    font-size: 12px; font-family: var(--font);
    padding: 6px 10px; border-radius: 4px;
    text-align: left;
  }
  .sidebar-action:hover { background: var(--surface2); color: var(--text); }
  .sidebar-action[disabled] { opacity: 0.4; cursor: default; }
  .sidebar-action[disabled]:hover { background: none; color: var(--text-muted); }

  /* ── SVG icons ── */
  .icon {
    width: 16px; height: 16px;
    stroke: currentColor; fill: none;
    stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: round;
    flex-shrink: 0;
  }

  /* ── icon button ── */
  .icon-btn {
    background: none; border: none; cursor: pointer;
    color: var(--text-muted); padding: 4px; border-radius: 3px;
    line-height: 1; transition: color 0.15s, background 0.15s;
    display: inline-flex; align-items: center; justify-content: center;
  }
  .icon-btn:hover { color: var(--text); background: var(--surface2); }

  /* ── notes list panel ── */
  .notes-panel {
    width: 280px;
    flex-shrink: 0;
    border-right: 1px solid var(--border);
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }
  .notes-panel-header {
    height: 41px;
    padding: 0 12px;
    font-size: 12px;
    font-weight: 600;
    color: var(--text-muted);
    border-bottom: 1px solid var(--border);
    display: flex; align-items: center; gap: 6px;
    flex-shrink: 0;
  }
  #folder-label { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .notes-list { flex: 1; overflow-y: auto; }
  .item-row {
    display: flex; align-items: center; gap: 10px;
    padding: 10px 12px;
    cursor: pointer;
    border-bottom: 1px solid var(--border);
    transition: background 0.1s;
  }
  .item-row:hover { background: var(--surface2); }
  .item-row.active { background: rgba(124,106,247,0.15); border-left: 2px solid var(--accent); padding-left: 10px; }
  .item-icon { flex-shrink: 0; opacity: 0.7; line-height: 1; display: flex; align-items: center; }
  .item-body { flex: 1; min-width: 0; }
  .item-title { font-size: 13px; font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .item-meta { font-size: 11px; color: var(--text-muted); margin-top: 2px; }
  .item-row.is-folder .item-title { font-weight: 500; }
  .empty-state { padding: 24px 12px; text-align: center; color: var(--text-muted); font-size: 12px; }
  .folder-up-btn { color: var(--text-muted); }
  .folder-up-btn:hover { color: var(--text); }

  /* ── editor ── */
  .editor-panel {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    min-width: 0;
  }
  .editor-toolbar {
    height: 41px;
    padding: 0 16px;
    border-bottom: 1px solid var(--border);
    display: flex; align-items: center; gap: 8px;
    flex-shrink: 0;
  }
  #note-title-input {
    flex: 1;
    background: none;
    border: none;
    outline: none;
    color: var(--text);
    font-size: 16px;
    font-weight: 600;
    font-family: var(--font);
  }
  #note-title-input::placeholder { color: var(--text-muted); font-weight: 400; }
  .save-btn {
    background: var(--accent); border: none; color: #fff;
    padding: 5px 12px; border-radius: 5px; cursor: pointer;
    font-size: 12px; font-weight: 600;
    transition: background 0.15s, opacity 0.15s;
  }
  .save-btn:hover { background: var(--accent-hover); }
  .save-btn:disabled { opacity: 0.4; cursor: default; }
  .save-status { font-size: 11px; color: var(--text-muted); }

  /* ── overflow menu ── */
  .overflow-wrap { position: relative; }
  .overflow-menu {
    display: none;
    position: absolute;
    top: 100%;
    right: 0;
    margin-top: 4px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 6px;
    box-shadow: 0 8px 24px rgba(0,0,0,0.4);
    min-width: 140px;
    z-index: 50;
    padding: 4px 0;
  }
  .overflow-menu.open { display: block; }
  .overflow-menu button {
    display: block;
    width: 100%;
    text-align: left;
    background: none;
    border: none;
    color: var(--text);
    padding: 7px 12px;
    font-size: 13px;
    font-family: var(--font);
    cursor: pointer;
  }
  .overflow-menu button:hover { background: var(--surface2); }
  .overflow-menu button.danger { color: var(--danger); }
  .overflow-menu button.danger:hover { background: rgba(224,92,92,0.1); }

  #editor {
    flex: 1;
    resize: none;
    background: var(--bg);
    color: var(--text);
    border: none;
    outline: none;
    padding: 20px 24px;
    font-family: var(--mono);
    font-size: 13.5px;
    line-height: 1.7;
    overflow-y: auto;
  }
  #editor::placeholder { color: var(--text-muted); font-family: var(--font); }

  #preview {
    flex: 1;
    padding: 20px 24px;
    overflow-y: auto;
    font-size: 14px;
    line-height: 1.7;
  }
  #preview h1 { font-size: 1.8em; margin: 0.5em 0 0.3em; border-bottom: 1px solid var(--border); padding-bottom: 0.2em; }
  #preview h2 { font-size: 1.4em; margin: 0.5em 0 0.3em; border-bottom: 1px solid var(--border); padding-bottom: 0.2em; }
  #preview h3 { font-size: 1.15em; margin: 0.5em 0 0.3em; }
  #preview h4, #preview h5, #preview h6 { font-size: 1em; margin: 0.4em 0 0.2em; }
  #preview p { margin: 0.5em 0; }
  #preview pre { background: var(--surface); padding: 12px 16px; border-radius: 6px; overflow-x: auto; margin: 0.6em 0; }
  #preview code { font-family: var(--mono); font-size: 0.9em; }
  #preview :not(pre) > code { background: var(--surface2); padding: 2px 5px; border-radius: 3px; }
  #preview blockquote { border-left: 3px solid var(--accent); padding-left: 14px; color: var(--text-muted); margin: 0.5em 0; }
  #preview ul, #preview ol { padding-left: 1.5em; margin: 0.4em 0; }
  #preview li { margin: 0.15em 0; }
  #preview li > input[type="checkbox"] { margin-right: 0.4em; }
  #preview a { color: var(--accent); text-decoration: none; }
  #preview a:hover { text-decoration: underline; }
  #preview hr { border: none; border-top: 1px solid var(--border); margin: 1em 0; }
  #preview img { max-width: 100%; border-radius: 6px; }
  #preview table { border-collapse: collapse; margin: 0.6em 0; }
  #preview th, #preview td { border: 1px solid var(--border); padding: 6px 12px; }
  #preview th { background: var(--surface); }

  /* ── modal ── */
  .modal-backdrop {
    position: fixed; inset: 0; background: rgba(0,0,0,0.6);
    display: none; align-items: center; justify-content: center;
    z-index: 100;
  }
  .modal-backdrop.open { display: flex; }
  .modal {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 20px;
    width: 320px;
    box-shadow: 0 16px 48px rgba(0,0,0,0.5);
  }
  .modal h3 { font-size: 14px; margin-bottom: 14px; }
  .modal input, .modal select {
    width: 100%; background: var(--bg); border: 1px solid var(--border);
    color: var(--text); padding: 8px 10px; border-radius: 5px;
    font-size: 13px; font-family: var(--font); outline: none;
    margin-bottom: 12px;
  }
  .modal input:focus, .modal select:focus { border-color: var(--accent); }
  .modal-actions { display: flex; gap: 8px; justify-content: flex-end; }
  .modal-choices { display: flex; flex-direction: column; gap: 8px; margin-bottom: 14px; }
  .modal-choice {
    display: flex; flex-direction: column; gap: 2px;
    padding: 10px 12px; border-radius: 6px;
    background: var(--bg); border: 1px solid var(--border);
    cursor: pointer; text-align: left; color: var(--text);
  }
  .modal-choice:hover { border-color: var(--accent); }
  .modal-choice-title { font-size: 13px; font-weight: 500; }
  .modal-choice-desc { font-size: 11px; color: var(--text-muted); }
  .btn { padding: 6px 14px; border-radius: 5px; font-size: 13px; cursor: pointer; border: none; font-family: var(--font); }
  .btn-primary { background: var(--accent); color: #fff; }
  .btn-primary:hover { background: var(--accent-hover); }
  .btn-secondary { background: var(--surface2); color: var(--text); border: 1px solid var(--border); }
  .btn-secondary:hover { border-color: var(--text-muted); }

  /* ── connect panel ── */
  #connect-panel {
    position: fixed; inset: 0; background: var(--bg);
    display: flex; align-items: center; justify-content: center;
    z-index: 200;
    flex-direction: column; gap: 12px;
  }
  #connect-panel h2 { font-size: 18px; margin-bottom: 4px; }
  #connect-panel p { font-size: 13px; color: var(--text-muted); }
  #connect-panel input {
    width: 300px; background: var(--surface); border: 1px solid var(--border);
    color: var(--text); padding: 9px 12px; border-radius: 6px;
    font-size: 13px; font-family: var(--font); outline: none;
  }
  #connect-panel input:focus { border-color: var(--accent); }
  #connect-error { color: var(--danger); font-size: 12px; min-height: 16px; }

  /* scrollbars */
  ::-webkit-scrollbar { width: 4px; }
  ::-webkit-scrollbar-track { background: transparent; }
  ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 2px; }

  /* ── back button (hidden on desktop) ── */
  .back-btn {
    display: none;
    background: none; border: none; cursor: pointer;
    color: var(--accent); font-size: 13px; font-family: var(--font);
    padding: 2px 6px; margin-right: 4px; border-radius: 3px;
  }
  .back-btn:hover { background: var(--surface2); }

  /* ── mobile responsive ── */
  @media (max-width: 640px) {
    .back-btn { display: inline-flex; align-items: center; }

    .layout { position: relative; }
    .sidebar, .notes-panel, .editor-panel {
      position: absolute;
      inset: 0;
      width: 100% !important;
      border: none !important;
      transition: transform 0.2s ease;
    }

    /* Default: sidebar visible, others off-screen right */
    .sidebar  { transform: translateX(0); z-index: 3; }
    .notes-panel { transform: translateX(100%); z-index: 2; }
    .editor-panel { transform: translateX(100%); z-index: 1; }

    /* View: notes-list */
    .layout[data-view="notes"] .sidebar { transform: translateX(-100%); }
    .layout[data-view="notes"] .notes-panel { transform: translateX(0); }
    .layout[data-view="notes"] .editor-panel { transform: translateX(100%); }

    /* View: editor */
    .layout[data-view="editor"] .sidebar { transform: translateX(-100%); }
    .layout[data-view="editor"] .notes-panel { transform: translateX(-100%); }
    .layout[data-view="editor"] .editor-panel { transform: translateX(0); }

    header h1 { font-size: 16px; }
    #ship-label { font-size: 12px; }

    .sidebar-section { font-size: 11px; height: 44px; padding: 0 12px; }
    .nb-item { font-size: 16px; padding: 10px 12px; }
    .nb-item .nb-icon .icon { width: 18px; height: 18px; }
    .sidebar-action { font-size: 14px; padding: 10px 12px; gap: 10px; }

    .notes-panel-header { height: 44px; font-size: 14px; padding: 0 12px; }
    .item-row { padding: 14px 12px; gap: 12px; }
    .item-icon .icon { width: 18px; height: 18px; }
    .item-title { font-size: 16px; }
    .item-meta { font-size: 13px; }
    .empty-state { font-size: 14px; }

    .editor-toolbar { height: 44px; padding: 0 10px; gap: 6px; }
    #note-title-input { font-size: 17px; min-width: 0; }
    #editor { padding: 16px 14px; font-size: 15px; line-height: 1.6; }
    #preview { padding: 16px 14px; font-size: 15px; }

    .sidebar { overflow-y: auto; }
    .notes-panel { overflow-y: auto; }

    .modal { width: calc(100vw - 32px); max-width: 320px; }
  }
</style>
</head>
<body>

<!-- SVG icon sprite -->
<svg xmlns="http://www.w3.org/2000/svg" style="display:none">
  <symbol id="i-notebook" viewBox="0 0 16 16">
    <rect x="3" y="1.5" width="10" height="13" rx="1.5"/>
    <line x1="6" y1="1.5" x2="6" y2="14.5"/>
  </symbol>
  <symbol id="i-folder" viewBox="0 0 16 16">
    <path d="M1.5 4a1 1 0 011-1H6l1.5 1.5H13.5a1 1 0 011 1V12a1 1 0 01-1 1h-11a1 1 0 01-1-1z"/>
  </symbol>
  <symbol id="i-doc" viewBox="0 0 16 16">
    <path d="M9.5 1.5H5a1 1 0 00-1 1v11a1 1 0 001 1h6a1 1 0 001-1V4z"/>
    <polyline points="9.5,1.5 9.5,4 12,4"/>
  </symbol>
  <symbol id="i-folder-plus" viewBox="0 0 16 16">
    <path d="M1.5 4a1 1 0 011-1H6l1.5 1.5H13.5a1 1 0 011 1V12a1 1 0 01-1 1h-11a1 1 0 01-1-1z"/>
    <line x1="8" y1="7" x2="8" y2="11"/><line x1="6" y1="9" x2="10" y2="9"/>
  </symbol>
  <symbol id="i-doc-plus" viewBox="0 0 16 16">
    <path d="M9.5 1.5H5a1 1 0 00-1 1v11a1 1 0 001 1h6a1 1 0 001-1V4z"/>
    <polyline points="9.5,1.5 9.5,4 12,4"/>
    <line x1="8" y1="7.5" x2="8" y2="11.5"/><line x1="6" y1="9.5" x2="10" y2="9.5"/>
  </symbol>
  <symbol id="i-plus" viewBox="0 0 16 16">
    <line x1="8" y1="3.5" x2="8" y2="12.5"/><line x1="3.5" y1="8" x2="12.5" y2="8"/>
  </symbol>
  <symbol id="i-arrow-up" viewBox="0 0 16 16">
    <line x1="8" y1="13" x2="8" y2="3"/><polyline points="4,7 8,3 12,7"/>
  </symbol>
  <symbol id="i-download" viewBox="0 0 16 16">
    <line x1="8" y1="2" x2="8" y2="10"/><polyline points="5,7 8,10 11,7"/>
    <path d="M3 13h10"/>
  </symbol>
  <symbol id="i-folder-down" viewBox="0 0 16 16">
    <path d="M1.5 4a1 1 0 011-1H6l1.5 1.5H13.5a1 1 0 011 1V12a1 1 0 01-1 1h-11a1 1 0 01-1-1z"/>
    <line x1="8" y1="6.5" x2="8" y2="10.5"/><polyline points="6,9 8,11 10,9"/>
  </symbol>
  <symbol id="i-eye" viewBox="0 0 16 16">
    <path d="M1.5 8s2.5-4 6.5-4 6.5 4 6.5 4-2.5 4-6.5 4S1.5 8 1.5 8z"/>
    <circle cx="8" cy="8" r="2"/>
  </symbol>
  <symbol id="i-ellipsis" viewBox="0 0 16 16" fill="currentColor" stroke="none">
    <circle cx="4" cy="8" r="1.2"/><circle cx="8" cy="8" r="1.2"/><circle cx="12" cy="8" r="1.2"/>
  </symbol>
  <symbol id="i-globe" viewBox="0 0 16 16">
    <circle cx="8" cy="8" r="6.5"/>
    <ellipse cx="8" cy="8" rx="3" ry="6.5"/>
    <line x1="1.5" y1="8" x2="14.5" y2="8"/>
  </symbol>
</svg>

<!-- Connect panel (shown until URL + auth set) -->
<div id="connect-panel">
  <h2><svg class="icon" style="width:20px;height:20px;vertical-align:-3px;margin-right:4px"><use href="#i-notebook"/></svg>Notes</h2>
  <p>Enter your ship URL to connect</p>
  <input id="ship-url-input" type="text" placeholder="http://localhost:8080" autocomplete="off" />
  <input id="auth-input" type="password" placeholder="+code (or leave blank if already logged in)" autocomplete="off" />
  <div id="connect-error"></div>
  <button class="btn btn-primary" onclick="connect()">Connect</button>
</div>

<header>
  <h1><svg class="icon" style="width:18px;height:18px;vertical-align:-3px;margin-right:4px"><use href="#i-notebook"/></svg>Notes</h1>
  <span id="ship-label"></span>
  <div id="status-dot"></div>
</header>

<div class="layout">
  <!-- Sidebar: notebooks + import actions -->
  <div class="sidebar">
    <div class="sidebar-section">
      Notebooks
      <button class="icon-btn" title="Add notebook" onclick="openModal(&quot;add-notebook&quot;)"><svg class="icon"><use href="#i-plus"/></svg></button>
    </div>
    <div class="sidebar-list" id="notebooks-list"></div>
    <div class="sidebar-actions">
      <button class="sidebar-action" id="import-files-btn" onclick="triggerImport(false)"><svg class="icon"><use href="#i-download"/></svg> Import files</button>
      <button class="sidebar-action" id="import-folder-btn" onclick="triggerImport(true)"><svg class="icon"><use href="#i-folder-down"/></svg> Import folder</button>
    </div>
  </div>

  <!-- Folders + Notes interleaved -->
  <div class="notes-panel">
    <div class="notes-panel-header">
      <button class="back-btn" onclick="mobileBack('notebooks')" title="Back to notebooks">← </button>
      <button class="icon-btn folder-up-btn" id="folder-up-btn" onclick="folderUp()" style="display:none" title="Up one folder"><svg class="icon"><use href="#i-arrow-up"/></svg></button>
      <span id="folder-label">Notes</span>
      <button class="icon-btn" id="new-folder-btn" title="New folder" onclick="openModal('new-folder')" style="display:none"><svg class="icon"><use href="#i-folder-plus"/></svg></button>
      <button class="icon-btn" id="new-note-btn" title="New note" onclick="newNote()" style="display:none"><svg class="icon"><use href="#i-doc-plus"/></svg></button>
    </div>
    <div class="notes-list" id="notes-list"></div>
  </div>

  <!-- Editor -->
  <div class="editor-panel">
    <div class="editor-toolbar">
      <button class="back-btn" onclick="mobileBack('notes')" title="Back to notes">← </button>
      <input id="note-title-input" type="text" placeholder="Untitled" oninput="onEditorInput()" />
      <span class="save-status" id="save-status"></span>
      <button class="icon-btn" id="preview-btn" onclick="togglePreview()" title="Preview"><svg class="icon"><use href="#i-eye"/></svg></button>
      <button class="icon-btn" id="view-published-btn" onclick="viewPublished()" title="View published" style="display:none"><svg class="icon"><use href="#i-globe"/></svg></button>
      <div class="overflow-wrap" id="overflow-wrap" style="display:none">
        <button class="icon-btn" onclick="toggleOverflow()" title="More"><svg class="icon"><use href="#i-ellipsis"/></svg></button>
        <div class="overflow-menu" id="overflow-menu">
          <button id="publish-btn" onclick="publishNote();">Publish to web</button>
          <button id="unpublish-btn" onclick="unpublishNote();" style="display:none">Unpublish</button>
          <button onclick="deleteNote();" class="danger">Delete note</button>
        </div>
      </div>
    </div>
    <textarea id="editor" placeholder="Write in markdown…" oninput="onEditorInput()"></textarea>
    <div id="preview" style="display:none"></div>
  </div>
</div>

<!-- Modals -->
<div class="modal-backdrop" id="modal-backdrop" onclick="closeModal(event)">
  <div class="modal" id="modal-box">
    <!-- filled dynamically -->
  </div>
</div>

<script>
// ── State ──────────────────────────────────────────────────────────────────
let BASE_URL = "";
let SHIP = "";
let channelId = "";
let eventSource = null;
let msgId = 1;

let notebooks = {};   // id -> notebook
let folders = {};     // id -> folder
let notes = {};       // id -> note
let publishedIds = new Set();  // set of published note IDs

let activeNotebookId = null;   // numeric id
let activeNotebookFlag = null; // "~ship/name" for scry paths
let activeFolderId = null;
let activeNoteId = null;
let dirty = false;
let savedRevision = 0;

// ── Connect ────────────────────────────────────────────────────────────────
async function connect() {
  const url = document.getElementById("ship-url-input").value.trim().replace(/\/$/, "");
  const code = document.getElementById("auth-input").value.trim();
  const errEl = document.getElementById("connect-error");
  const panel = document.getElementById("connect-panel");
  errEl.textContent = "";

  function fail(msg) { errEl.textContent = msg; panel.style.display = ""; }

  if (!url) { fail("Enter a URL"); return; }
  BASE_URL = url;

  // Optionally authenticate with +code
  if (code) {
    try {
      const params = new URLSearchParams({ password: code });
      const r = await fetch(`${BASE_URL}/~/login`, {
        method: "POST", credentials: "include",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: params.toString()
      });
      if (!r.ok && r.status !== 204) throw new Error(`Login failed: ${r.status}`);
    } catch(e) {
      fail(e.message); return;
    }
  }

  // Get ship name
  try {
    const r = await fetch(`${BASE_URL}/~/scry/notes/v0/notebooks.json`, { credentials: "include" });
    if (r.status === 403) { fail("Auth failed — check your +code"); return; }
    if (!r.ok && r.status !== 404) { fail(`Cannot reach ship: ${r.status}`); return; }
  } catch(e) { fail(`Cannot reach ship: ${e.message}`); return; }

  // Get own ship name
  try {
    const r = await fetch(`${BASE_URL}/~/name`, { credentials: "include" });
    if (r.ok) SHIP = (await r.text()).trim();
  } catch(e) {}

  document.getElementById("connect-panel").style.display = "none";
  document.getElementById("ship-label").textContent = SHIP || BASE_URL;
  document.getElementById("status-dot").className = "connected";

  openChannel();
  await loadNotebooks();
  await loadPublished();
  await restoreSelection();
}

function saveSelection() {
  localStorage.setItem('notes-selection', JSON.stringify({
    notebookId: activeNotebookId,
    folderId: activeFolderId,
    noteId: activeNoteId,
  }));
}

async function restoreSelection() {
  try {
    const saved = JSON.parse(localStorage.getItem('notes-selection') || '{}');
    if (saved.notebookId && notebooks[saved.notebookId]) {
      await selectNotebook(saved.notebookId);
      if (saved.folderId && folders[saved.folderId]) {
        activeFolderId = saved.folderId;
        renderItems();
      }
      if (saved.noteId && notes[saved.noteId]) {
        await selectNote(saved.noteId);
      }
    }
  } catch {}
}

// ── Eyre Channel ──────────────────────────────────────────────────────────
function openChannel() {
  channelId = `notes-ui-${Date.now()}`;
}

let activeSubscriptionId = null;

async function subscribeEvents() {
  if (!activeNotebookFlag) return;
  // Unsubscribe from previous notebook if any
  if (activeSubscriptionId !== null) {
    await poke([{
      id: msgId++, action: "unsubscribe",
      subscription: activeSubscriptionId
    }]);
    activeSubscriptionId = null;
  }
  // Subscribe to this notebook's stream
  const subId = msgId++;
  activeSubscriptionId = subId;
  await poke([{
    id: subId, action: "subscribe",
    ship: SHIP.replace("~",""),
    app: "notes", path: `/v0/notes/${activeNotebookFlag}/stream`
  }]);
  // Start SSE after the channel is created by the PUT
  startSSE();
}

function startSSE() {
  if (eventSource) eventSource.close();
  eventSource = new EventSource(`${BASE_URL}/~/channel/${channelId}`, { withCredentials: true });
  eventSource.onmessage = (e) => {
    try {
      const msg = JSON.parse(e.data);
      handleEvent(msg);
    } catch {}
  };
  eventSource.onerror = () => {
    document.getElementById("status-dot").className = "error";
  };
  eventSource.onopen = () => {
    document.getElementById("status-dot").className = "connected";
  };
}

async function poke(actions) {
  await fetch(`${BASE_URL}/~/channel/${channelId}`, {
    method: "PUT",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(actions)
  });
}

async function pokeAction(action) {
  const id = msgId++;
  // Include _flag for unambiguous notebook routing across ships
  if (activeNotebookFlag) {
    action._flag = activeNotebookFlag;
  }
  await poke([{
    id, action: "poke",
    ship: SHIP.replace("~",""),
    app: "notes",
    mark: "notes-action",
    json: action
  }]);
}

async function scry(path) {
  const r = await fetch(`${BASE_URL}/~/scry/notes${path}.json`, { credentials: "include" });
  if (!r.ok) return null;
  return r.json();
}

// ── Event Handling ────────────────────────────────────────────────────────
function handleEvent(msg) {
  if (!msg.json) return;
  const data = msg.json;

  // Handle response envelope from /stream subscription
  if (data.response === "snapshot") {
    // Full reload on snapshot
    loadNotebooks();
    return;
  }
  if (data.response === "update") {
    const evt = data.update;
    const type = evt.type;
    // Reload relevant data on events
    if (type === "notebook-created" || type === "notebook-renamed") loadNotebooks();
    else if (type?.startsWith("folder-")) loadFolders(activeNotebookId);
    else if (type?.startsWith("note-")) {
      loadNotes(activeNotebookId);
      // If the note we are editing was updated remotely
      if (type === "note-updated" && evt.noteId === activeNoteId && !dirty) {
        loadNote(activeNoteId);
      }
    }
    return;
  }

  // Fallback: try handling as a raw event (backwards compat)
  const type = data.type;
  if (type === "notebook-created" || type === "notebook-renamed") loadNotebooks();
  else if (type?.startsWith("folder-")) loadFolders(activeNotebookId);
  else if (type?.startsWith("note-")) {
    loadNotes(activeNotebookId);
    if (type === "note-updated" && data.noteId === activeNoteId && !dirty) {
      loadNote(activeNoteId);
    }
  }
}

// ── Load Data ─────────────────────────────────────────────────────────────
async function loadPublished() {
  const data = await scry("/v0/published");
  publishedIds = new Set(data || []);
}

async function loadNotebooks() {
  const data = await scry("/v0/notebooks");
  if (!data) return;
  notebooks = {};
  (data || []).forEach(entry => {
    const nb = entry.notebook;
    nb.host = entry.host;
    nb.flagName = entry.flagName;
    nb.flag = `${entry.host}/${entry.flagName}`;
    notebooks[nb.id] = nb;
  });
  renderNotebooks();
}

async function loadFolders(notebookId) {
  if (!activeNotebookFlag) return;
  const data = await scry(`/v0/folders/${activeNotebookFlag}`);
  folders = {};
  (data || []).forEach(f => folders[f.id] = f);
  // Default to root folder if no valid folder is selected
  if (!activeFolderId || !folders[activeFolderId]) {
    const rootFolder = Object.values(folders).find(f => f.name === "/");
    activeFolderId = rootFolder ? rootFolder.id : null;
  }
  renderItems();
}

async function loadNotes(notebookId) {
  if (!activeNotebookFlag) return;
  const data = await scry(`/v0/notes/${activeNotebookFlag}`);
  notes = {};
  (data || []).forEach(n => notes[n.id] = n);
  renderItems();
}

function rootFolderId() {
  const root = Object.values(folders).find(f => f.name === "/");
  return root ? root.id : null;
}

async function loadNote(noteId) {
  // reload all notes to get fresh data, then update editor if needed
  if (!activeNotebookFlag) return;
  const data = await scry(`/v0/notes/${activeNotebookFlag}`);
  if (!data) return;
  (data || []).forEach(n => notes[n.id] = n);
  const n = notes[noteId];
  if (!n) return;
  if (activeNoteId === n.id) {
    document.getElementById("note-title-input").value = n.title;
    document.getElementById("editor").value = n.bodyMd;
    savedRevision = n.revision;
    clearDirty();
  }
}

// ── Render ────────────────────────────────────────────────────────────────
function renderNotebooks() {
  const el = document.getElementById("notebooks-list");
  el.innerHTML = "";
  Object.values(notebooks).sort((a,b) => a.title.localeCompare(b.title)).forEach(nb => {
    const div = document.createElement("div");
    div.className = "nb-item" + (nb.id === activeNotebookId ? " active" : "");
    div.innerHTML = `<span class="nb-icon">${icon('notebook')}</span><span class="nb-name">${esc(nb.title)}</span><span class="nb-flag" title="Click to copy flag">${esc(nb.flag)}</span>`;
    div.onclick = () => selectNotebook(nb.id);
    div.querySelector(".nb-flag").onclick = (e) => {
      e.stopPropagation();
      navigator.clipboard.writeText(nb.flag);
      const el = e.target;
      const orig = el.textContent;
      el.textContent = "copied!";
      setTimeout(() => el.textContent = orig, 1000);
    };
    el.appendChild(div);
  });
}

function updateHeader() {
  const labelEl = document.getElementById("folder-label");
  const upBtn = document.getElementById("folder-up-btn");
  const newFolderBtn = document.getElementById("new-folder-btn");
  const newNoteBtn = document.getElementById("new-note-btn");
  if (!activeNotebookId) {
    labelEl.textContent = "Notes";
    upBtn.style.display = "none";
    newFolderBtn.style.display = "none";
    newNoteBtn.style.display = "none";
    return;
  }
  newFolderBtn.style.display = "";
  newNoteBtn.style.display = "";
  const rootId = rootFolderId();
  const isAtRoot = !activeFolderId || activeFolderId === rootId;
  if (isAtRoot) {
    labelEl.textContent = notebooks[activeNotebookId]?.title || "Notes";
    upBtn.style.display = "none";
  } else {
    labelEl.textContent = folders[activeFolderId]?.name || "Folder";
    upBtn.style.display = "";
  }
}

function renderItems() {
  updateHeader();
  const el = document.getElementById("notes-list");
  el.innerHTML = "";
  if (!activeNotebookId || !activeFolderId) return;

  const subfolders = Object.values(folders)
    .filter(f => f.parentFolderId === activeFolderId && f.name !== "/")
    .sort((a,b) => a.name.localeCompare(b.name));

  const notesHere = Object.values(notes)
    .filter(n => n.folderId === activeFolderId)
    .sort((a,b) => b.updatedAt - a.updatedAt);

  if (!subfolders.length && !notesHere.length) {
    el.innerHTML = "<div class=\"empty-state\">Empty folder</div>";
    return;
  }

  subfolders.forEach(f => {
    const div = document.createElement("div");
    div.className = "item-row is-folder";
    div.innerHTML = `
      <span class="item-icon">${icon('folder')}</span>
      <div class="item-body">
        <div class="item-title">${esc(f.name)}</div>
      </div>
    `;
    div.onclick = () => navigateToFolder(f.id);
    el.appendChild(div);
  });

  notesHere.forEach(n => {
    const div = document.createElement("div");
    div.className = "item-row is-note" + (n.id === activeNoteId ? " active" : "");
    const d = new Date(n.updatedAt * 1000);
    const dateStr = d.toLocaleDateString(undefined, { month:"short", day:"numeric" });
    div.innerHTML = `
      <span class="item-icon">${icon('doc')}</span>
      <div class="item-body">
        <div class="item-title">${esc(n.title)}</div>
        <div class="item-meta">${dateStr} · rev ${n.revision}</div>
      </div>
    `;
    div.onclick = () => selectNote(n.id);
    el.appendChild(div);
  });
}

async function navigateToFolder(id) {
  if (!await confirmDirty()) return;
  activeFolderId = id;
  activeNoteId = null;
  clearEditor();
  renderItems();
  saveSelection();
}

async function folderUp() {
  if (!activeFolderId) return;
  const f = folders[activeFolderId];
  if (!f) return;
  const rootId = rootFolderId();
  if (activeFolderId === rootId) return;
  await navigateToFolder(f.parentFolderId || rootId);
}

// ── Import ────────────────────────────────────────────────────────────────
function triggerImport(isFolder) {
  if (!activeNotebookId) { alert("Select a notebook first"); return; }
  const input = document.createElement("input");
  input.type = "file";
  if (isFolder) {
    input.webkitdirectory = true;
  } else {
    input.multiple = true;
    input.accept = ".md,.txt,.markdown,.text";
  }
  input.onchange = async (e) => {
    const allFiles = Array.from(e.target.files);
    const mdFiles = allFiles.filter(f => /\.(md|txt|markdown|text)$/i.test(f.name));
    if (!mdFiles.length) { alert("No .md or .txt files found"); return; }
    document.getElementById("save-status").textContent = "Importing " + mdFiles.length + " files…";

    let folderId = activeFolderId;
    if (!folderId) {
      const rootFolder = Object.values(folders).find(f => f.name === "/");
      if (rootFolder) folderId = rootFolder.id;
      else { alert("No folders found"); return; }
    }

    if (isFolder) {
      // Build tree from webkitRelativePath
      const tree = [];
      for (const file of mdFiles) {
        const parts = file.webkitRelativePath.split("/");
        // parts[0] is root folder name, rest are subfolders + filename
        let node = tree;
        // skip parts[0] (selected folder name) and last (filename)
        for (let i = 1; i < parts.length - 1; i++) {
          let existing = node.find(n => n.children && n.name === parts[i]);
          if (!existing) {
            existing = { name: parts[i], children: [] };
            node.push(existing);
          }
          node = existing.children;
        }
        const text = await file.text();
        const title = file.name.replace(/\.(md|txt|markdown|text)$/i, "");
        node.push({ title, bodyMd: text });
      }
      await pokeAction({
        "batch-import-tree": {
          notebookId: activeNotebookId,
          parentFolderId: folderId,
          tree: tree
        }
      });
    } else {
      const noteItems = [];
      for (const file of mdFiles) {
        const text = await file.text();
        const title = file.name.replace(/\.(md|txt|markdown|text)$/i, "");
        noteItems.push({ title, bodyMd: text });
      }
      await pokeAction({
        "batch-import": {
          notebookId: activeNotebookId,
          folderId: folderId,
          notes: noteItems
        }
      });
    }

    setTimeout(async () => {
      await loadFolders(activeNotebookId);
      await loadNotes(activeNotebookId);
      document.getElementById("save-status").textContent = "Imported " + mdFiles.length + " notes";
      setTimeout(() => { document.getElementById("save-status").textContent = ""; }, 3000);
    }, 500);
  };
  document.body.appendChild(input);
  input.click();
  input.remove();
}

// ── Markdown Preview ──────────────────────────────────────────────────────
let previewMode = false;

function togglePreview() {
  previewMode = !previewMode;
  const editor = document.getElementById("editor");
  const preview = document.getElementById("preview");
  const btn = document.getElementById("preview-btn");
  if (previewMode) {
    preview.innerHTML = renderMarkdown(editor.value);
    editor.style.display = "none";
    preview.style.display = "block";
    btn.style.color = "var(--accent)";
  } else {
    editor.style.display = "block";
    preview.style.display = "none";
    btn.style.color = "";
  }
}

function renderMarkdown(src) {
  // escape HTML
  const esc = s => s.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
  const lines = src.split("\n");
  let html = "";
  let inCode = false, codeLang = "", codeLines = [];
  let inList = false, listType = "";
  let inBlockquote = false;

  function flushList() {
    if (inList) { html += listType === "ul" ? "</ul>\n" : "</ol>\n"; inList = false; }
  }
  function flushBlockquote() {
    if (inBlockquote) { html += "</blockquote>\n"; inBlockquote = false; }
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // fenced code blocks
    if (/^```/.test(line)) {
      if (!inCode) {
        flushList(); flushBlockquote();
        codeLang = line.slice(3).trim();
        codeLines = [];
        inCode = true;
        continue;
      } else {
        html += "<pre><code" + (codeLang ? " class=\"language-" + esc(codeLang) + "\"" : "") + ">" + esc(codeLines.join("\n")) + "</code></pre>\n";
        inCode = false;
        continue;
      }
    }
    if (inCode) { codeLines.push(line); continue; }

    // blank line
    if (!line.trim()) { flushList(); flushBlockquote(); html += "\n"; continue; }

    // headings
    const hm = line.match(/^(#{1,6})\s+(.*)/);
    if (hm) { flushList(); flushBlockquote(); const lvl = hm[1].length; html += "<h" + lvl + ">" + inline(hm[2]) + "</h" + lvl + ">\n"; continue; }

    // hr
    if (/^([-*_]\s*){3,}$/.test(line.trim())) { flushList(); flushBlockquote(); html += "<hr>\n"; continue; }

    // blockquote
    if (/^>\s?/.test(line)) {
      flushList();
      const content = line.replace(/^>\s?/, "");
      if (!inBlockquote) { html += "<blockquote>\n"; inBlockquote = true; }
      html += "<p>" + inline(content) + "</p>\n";
      continue;
    } else { flushBlockquote(); }

    // unordered list
    const ulm = line.match(/^(\s*)[-*+]\s+(.*)/);
    if (ulm) {
      if (!inList || listType !== "ul") { flushList(); html += "<ul>\n"; inList = true; listType = "ul"; }
      // checkbox
      const cbm = ulm[2].match(/^\[([ xX])\]\s*(.*)/);
      if (cbm) {
        const checked = cbm[1] !== " " ? " checked disabled" : " disabled";
        html += "<li><input type=\"checkbox\"" + checked + "> " + inline(cbm[2]) + "</li>\n";
      } else {
        html += "<li>" + inline(ulm[2]) + "</li>\n";
      }
      continue;
    }

    // ordered list
    const olm = line.match(/^(\s*)\d+[.)]\s+(.*)/);
    if (olm) {
      if (!inList || listType !== "ol") { flushList(); html += "<ol>\n"; inList = true; listType = "ol"; }
      html += "<li>" + inline(olm[2]) + "</li>\n";
      continue;
    }

    flushList();
    // table
    if (line.includes("|") && i + 1 < lines.length && /^[\s|:-]+$/.test(lines[i + 1])) {
      const parseRow = r => r.split("|").map(c => c.trim()).filter(c => c !== "");
      const headers = parseRow(line);
      html += "<table><thead><tr>" + headers.map(h => "<th>" + inline(h) + "</th>").join("") + "</tr></thead><tbody>\n";
      i++; // skip separator
      while (i + 1 < lines.length && lines[i + 1].includes("|")) {
        i++;
        const cells = parseRow(lines[i]);
        html += "<tr>" + cells.map(c => "<td>" + inline(c) + "</td>").join("") + "</tr>\n";
      }
      html += "</tbody></table>\n";
      continue;
    }

    // paragraph
    html += "<p>" + inline(line) + "</p>\n";
  }
  if (inCode) html += "<pre><code>" + esc(codeLines.join("\n")) + "</code></pre>\n";
  flushList(); flushBlockquote();
  return html;
}

function inline(s) {
  const esc = t => t.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
  // inline code first (to protect contents)
  let result = "";
  let rest = s;
  while (rest) {
    const cm = rest.match(/`([^`]+)`/);
    if (!cm) { result += rest; break; }
    result += rest.slice(0, cm.index);
    result += "<code>" + esc(cm[1]) + "</code>";
    rest = rest.slice(cm.index + cm[0].length);
  }
  s = result;
  // images before links
  s = s.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, "<img src=\"$2\" alt=\"$1\">");
  // links
  s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, "<a href=\"$2\" target=\"_blank\">$1</a>");
  // bold+italic
  s = s.replace(/\*\*\*(.+?)\*\*\*/g, "<strong><em>$1</em></strong>");
  s = s.replace(/___(.+?)___/g, "<strong><em>$1</em></strong>");
  // bold
  s = s.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
  s = s.replace(/__(.+?)__/g, "<strong>$1</strong>");
  // italic
  s = s.replace(/\*(.+?)\*/g, "<em>$1</em>");
  s = s.replace(/_(.+?)_/g, "<em>$1</em>");
  // strikethrough
  s = s.replace(/~~(.+?)~~/g, "<del>$1</del>");
  return s;
}

// ── Selection ─────────────────────────────────────────────────────────────
async function selectNotebook(id) {
  if (!await confirmDirty()) return;
  activeNotebookId = id;
  const nb = notebooks[id];
  activeNotebookFlag = nb ? nb.flag : null;
  activeFolderId = null;  // loadFolders will set this to root folder id
  activeNoteId = null;
  clearEditor();
  renderNotebooks();
  await loadFolders(id);
  await loadNotes(id);
  subscribeEvents();
  saveSelection();
  if (isMobile()) mobileSetView("notes");
}

async function selectNote(id) {
  if (!await confirmDirty()) return;
  activeNoteId = id;
  renderItems();
  const n = notes[id];
  document.getElementById("note-title-input").value = n.title;
  document.getElementById("editor").value = n.bodyMd;
  if (previewMode) document.getElementById("preview").innerHTML = renderMarkdown(n.bodyMd);
  savedRevision = n.revision;
  clearDirty();
  document.getElementById("overflow-wrap").style.display = "";
  saveSelection();
  // Update publish/unpublish button state
  const isPublished = publishedIds.has(id);
  document.getElementById("publish-btn").style.display = isPublished ? "none" : "";
  document.getElementById("unpublish-btn").style.display = isPublished ? "" : "none";
  document.getElementById("view-published-btn").style.display = isPublished ? "" : "none";
  if (isMobile()) mobileSetView("editor");
}

// ── Create / Save ─────────────────────────────────────────────────────────
async function newNote() {
  if (!activeNotebookId) { alert("Select a notebook first"); return; }
  if (!activeFolderId) { alert("No folder selected"); return; }
  if (!await confirmDirty()) return;

  await pokeAction({
    "create-note": { notebookId: activeNotebookId, folderId: activeFolderId, title: "Untitled", bodyMd: "" }
  });

  // Reload and select the newest note
  setTimeout(async () => {
    await loadNotes(activeNotebookId);
    const inFolder = Object.values(notes).filter(n => n.folderId === activeFolderId);
    const newest = inFolder.sort((a,b) => b.id - a.id)[0];
    if (newest) selectNote(newest.id);
  }, 300);
}

// ── Auto-save ────────────────────────────────────────────────────────────
let saveTimer = null;
let saving = false;

function onEditorInput() {
  dirty = true;
  document.getElementById("save-status").textContent = "";
  if (saveTimer) clearTimeout(saveTimer);
  saveTimer = setTimeout(() => autoSave(), 1500);
}

async function autoSave() {
  if (!activeNoteId || !dirty || saving) return;
  saving = true;
  const title = document.getElementById("note-title-input").value.trim() || "Untitled";
  const body = document.getElementById("editor").value;
  const n = notes[activeNoteId];
  if (!n) { saving = false; return; }

  document.getElementById("save-status").textContent = "Saving\u2026";

  try {
    // Use revision 0 (force-update) for remote notebooks where our
    // local revision may be stale; use real revision for local notebooks
    const nb = notebooks[n.notebookId];
    const isLocal = nb && nb.host === `~${SHIP}`;
    const rev = isLocal ? savedRevision : 0;
    await pokeAction({ "update-note": { notebookId: n.notebookId, noteId: activeNoteId, bodyMd: body, expectedRevision: rev } });
    if (isLocal) savedRevision++;
    if (title !== n.title) {
      await pokeAction({ "rename-note": { notebookId: n.notebookId, noteId: activeNoteId, title } });
    }
    notes[activeNoteId] = { ...n, title, bodyMd: body, revision: savedRevision };
    dirty = false;
    document.getElementById("save-status").textContent = "Saved";
    setTimeout(() => { if (!dirty) document.getElementById("save-status").textContent = ""; }, 2000);
    renderItems();
  } catch(e) {
    document.getElementById("save-status").textContent = "Error saving";
  }
  saving = false;
}

// keep ctrl+s as a force-save
async function saveNote() { if (saveTimer) clearTimeout(saveTimer); await autoSave(); }

// ── Overflow menu ────────────────────────────────────────────────────────
function toggleOverflow() {
  document.getElementById("overflow-menu").classList.toggle("open");
}

function closeOverflow() {
  document.getElementById("overflow-menu").classList.remove("open");
}

document.addEventListener("click", (e) => {
  if (!e.target.closest(".overflow-wrap")) closeOverflow();
});

async function deleteNote() {
  closeOverflow();
  if (!activeNoteId || !activeNotebookId) return;
  const n = notes[activeNoteId];
  if (!n) return;
  const title = n.title || "Untitled";
  if (!confirm(`Delete "${title}"? This cannot be undone.`)) return;

  await pokeAction({
    "delete-note": { noteId: activeNoteId, notebookId: activeNotebookId }
  });

  delete notes[activeNoteId];
  activeNoteId = null;
  clearEditor();
  renderItems();
  if (isMobile()) mobileSetView("notes");
}

// ── Publish ──────────────────────────────────────────────────────────────
function publishTemplate(title, bodyHtml) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${esc(title)}</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    background: #0f0f0f; color: #e8e8e8;
    line-height: 1.7; font-size: 16px;
    padding: 48px 24px;
  }
  article {
    max-width: 680px; margin: 0 auto;
  }
  h1 { font-size: 2em; margin-bottom: 0.4em; color: #fff; }
  h2 { font-size: 1.5em; margin: 1.4em 0 0.4em; color: #fff; }
  h3 { font-size: 1.25em; margin: 1.2em 0 0.3em; color: #fff; }
  h4, h5, h6 { margin: 1em 0 0.3em; color: #fff; }
  p { margin: 0.8em 0; }
  a { color: #7c6af7; text-decoration: none; }
  a:hover { text-decoration: underline; }
  code {
    font-family: "JetBrains Mono", "Fira Code", monospace;
    background: #1a1a1a; padding: 2px 5px; border-radius: 3px;
    font-size: 0.9em;
  }
  pre {
    background: #1a1a1a; padding: 16px; border-radius: 6px;
    overflow-x: auto; margin: 1em 0; border: 1px solid #2e2e2e;
  }
  pre code { background: none; padding: 0; }
  blockquote {
    border-left: 3px solid #7c6af7; padding-left: 16px;
    color: #999; margin: 1em 0;
  }
  ul, ol { padding-left: 24px; margin: 0.8em 0; }
  li { margin: 0.3em 0; }
  hr { border: none; border-top: 1px solid #2e2e2e; margin: 2em 0; }
  img { max-width: 100%; border-radius: 6px; }
  table { border-collapse: collapse; margin: 1em 0; width: 100%; }
  th, td { border: 1px solid #2e2e2e; padding: 8px 12px; text-align: left; }
  th { background: #1a1a1a; }
  .pub-footer {
    margin-top: 48px; padding-top: 16px;
    border-top: 1px solid #2e2e2e;
    font-size: 12px; color: #666;
  }
</style>
</head>
<body>
<article>
<h1>${esc(title)}</h1>
${bodyHtml}
<div class="pub-footer">Published from Urbit</div>
</article>
</body>
</html>`;
}

async function publishNote() {
  closeOverflow();
  if (!activeNoteId || !activeNotebookId) return;
  const n = notes[activeNoteId];
  if (!n) return;

  // Save first if dirty
  if (dirty) await autoSave();

  const body = document.getElementById("editor").value;
  const html = publishTemplate(n.title || "Untitled", renderMarkdown(body));

  await pokeAction({
    "publish-note": { notebookId: activeNotebookId, noteId: activeNoteId, html }
  });

  const pubUrl = `${BASE_URL}/notes/pub/${activeNoteId}`;
  publishedIds.add(activeNoteId);
  document.getElementById("publish-btn").style.display = "none";
  document.getElementById("unpublish-btn").style.display = "";
  document.getElementById("view-published-btn").style.display = "";
  window.open(pubUrl, '_blank');
}

async function unpublishNote() {
  closeOverflow();
  if (!activeNoteId || !activeNotebookId) return;

  await pokeAction({
    "unpublish-note": { notebookId: activeNotebookId, noteId: activeNoteId }
  });

  publishedIds.delete(activeNoteId);
  document.getElementById("publish-btn").style.display = "";
  document.getElementById("unpublish-btn").style.display = "none";
  document.getElementById("view-published-btn").style.display = "none";
}

function viewPublished() {
  if (!activeNoteId) return;
  window.open(`${BASE_URL}/notes/pub/${activeNoteId}`, '_blank');
}

// ── Dirty state ──────────────────────────────────────────────────────────
function clearDirty() {
  dirty = false;
  if (saveTimer) { clearTimeout(saveTimer); saveTimer = null; }
}

async function confirmDirty() {
  if (!dirty) return true;
  // Try to save first
  await autoSave();
  return true;
}

function clearEditor() {
  document.getElementById("note-title-input").value = "";
  document.getElementById("editor").value = "";
  document.getElementById("overflow-wrap").style.display = "none";
  clearDirty();
}

// ── Modal ─────────────────────────────────────────────────────────────────
function openModal(type) {
  const box = document.getElementById("modal-box");
  const backdrop = document.getElementById("modal-backdrop");

  if (type === "add-notebook") {
    box.innerHTML = `
      <h3>Add Notebook</h3>
      <div class="modal-choices">
        <button class="modal-choice" onclick="openModal('new-notebook')">
          <span class="modal-choice-title">Create new</span>
          <span class="modal-choice-desc">Start a fresh notebook</span>
        </button>
        <button class="modal-choice" onclick="openModal('join-notebook')">
          <span class="modal-choice-title">Join existing</span>
          <span class="modal-choice-desc">Enter a flag to join a shared notebook</span>
        </button>
      </div>
      <div class="modal-actions">
        <button class="btn btn-secondary" onclick="closeModal()">Cancel</button>
      </div>
    `;
  } else if (type === "new-notebook") {
    box.innerHTML = `
      <h3>New Notebook</h3>
      <input id="m-title" type="text" placeholder="Notebook title" autofocus />
      <div class="modal-actions">
        <button class="btn btn-secondary" onclick="closeModal()">Cancel</button>
        <button class="btn btn-primary" onclick="createNotebook()">Create</button>
      </div>
    `;
    box.querySelector("#m-title").addEventListener("keydown", e => { if (e.key==="Enter") createNotebook(); });
  } else if (type === "join-notebook") {
    box.innerHTML = `
      <h3>Join Notebook</h3>
      <input id="m-flag" type="text" placeholder="~sampel-palnet/notebook-name" autofocus />
      <div style="font-size:11px;color:var(--text-muted);margin:6px 0">Enter the flag shared by the notebook host</div>
      <div class="modal-actions">
        <button class="btn btn-secondary" onclick="closeModal()">Cancel</button>
        <button class="btn btn-primary" onclick="joinNotebook()">Join</button>
      </div>
    `;
    box.querySelector("#m-flag").addEventListener("keydown", e => { if (e.key==="Enter") joinNotebook(); });
  } else if (type === "new-folder") {
    if (!activeNotebookId) { alert("Select a notebook first"); return; }
    const rootId = rootFolderId();
    const isAtRoot = !activeFolderId || activeFolderId === rootId;
    const folderOpts = Object.values(folders)
      .filter(f => f.name !== "/")
      .map(f => `<option value="${f.id}"${f.id === activeFolderId ? " selected" : ""}>${esc(f.name)}</option>`)
      .join("");
    box.innerHTML = `
      <h3>New Folder</h3>
      <input id="m-name" type="text" placeholder="Folder name" autofocus />
      <select id="m-parent">
        <option value=""${isAtRoot ? " selected" : ""}>Root level</option>
        ${folderOpts}
      </select>
      <div class="modal-actions">
        <button class="btn btn-secondary" onclick="closeModal()">Cancel</button>
        <button class="btn btn-primary" onclick="createFolder()">Create</button>
      </div>
    `;
  }

  backdrop.classList.add("open");
  setTimeout(() => box.querySelector("input")?.focus(), 50);
}

function closeModal(e) {
  if (e && e.target !== document.getElementById("modal-backdrop")) return;
  document.getElementById("modal-backdrop").classList.remove("open");
}

async function createNotebook() {
  const title = document.getElementById("m-title")?.value?.trim();
  if (!title) return;
  document.getElementById("modal-backdrop").classList.remove("open");
  await pokeAction({ "create-notebook": title });
  setTimeout(() => loadNotebooks(), 300);
}

async function joinNotebook() {
  const flag = document.getElementById("m-flag")?.value?.trim();
  if (!flag || !flag.includes("/")) return;
  const parts = flag.split("/");
  const ship = parts[0].startsWith("~") ? parts[0] : "~" + parts[0];
  const name = parts.slice(1).join("/");
  document.getElementById("modal-backdrop").classList.remove("open");
  await pokeAction({ "join-remote": { ship, name } });
  setTimeout(() => loadNotebooks(), 2000);
}

async function createFolder() {
  const name = document.getElementById("m-name")?.value?.trim();
  const parentVal = document.getElementById("m-parent")?.value;
  if (!name) return;
  document.getElementById("modal-backdrop").classList.remove("open");

  // Find root folder if no parent selected
  let parentFolderId = parentVal ? parseInt(parentVal) : null;
  if (!parentFolderId) {
    const rootFolder = Object.values(folders).find(f => f.name === "/");
    parentFolderId = rootFolder ? rootFolder.id : null;
  }

  await pokeAction({
    "create-folder": {
      notebookId: activeNotebookId,
      parentFolderId: parentFolderId,
      name
    }
  });
  setTimeout(() => loadFolders(activeNotebookId), 300);
}

// ── Keyboard shortcuts ────────────────────────────────────────────────────
document.addEventListener("keydown", e => {
  if ((e.metaKey || e.ctrlKey) && e.key === "s") {
    e.preventDefault();
    if (dirty) saveNote();
  }
});

// ── Mobile Navigation ────────────────────────────────────────────────────
function isMobile() { return window.innerWidth <= 640; }

function mobileSetView(view) {
  document.querySelector(".layout").setAttribute("data-view", view);
}

function mobileBack(to) {
  if (to === "notebooks") mobileSetView("notebooks");
  else if (to === "notes") mobileSetView("notes");
}

// ── Util ──────────────────────────────────────────────────────────────────
function esc(s) {
  return String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
}
function icon(id) {
  return `<svg class="icon"><use href="#i-${id}"/></svg>`;
}

// Auto-connect when served from a ship
if (location.protocol !== "file:" && location.hostname) {
  // Hide connect panel immediately to avoid flash
  document.getElementById("connect-panel").style.display = "none";
  document.getElementById("ship-url-input").value = location.origin;
  connect().catch(() => {
    // Show connect panel if auto-connect fails
    document.getElementById("connect-panel").style.display = "";
  });
}

</script>
</body>
</html>
'''
