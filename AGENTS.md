# Notes Agent Development Guide

## Overview

`%notes` is an Urbit Gall agent for collaborative markdown notebooks. The frontend is a single-file HTML/CSS/JS app served inline from Hoon. See `SPEC.md` for the full product spec and roadmap, and `README.md` for the user-facing overview.

## Desk Structure

```
desk/
  app/notes.hoon           # Gall agent (state, pokes, peeks, watches, HTTP handler)
  app/notes-ui/index.html  # Working copy of the UI (source of truth for edits)
  sur/notes.hoon           # Type definitions (state-1..10, ACUR shapes, legacy v0/v8/v9 entity types)
  lib/notes-json.hoon      # JSON encoding/decoding for all types
  lib/notes-ui.hoon        # Generated file — the UI served to the browser
  mar/notes/action.hoon    # Client action mark
  mar/notes/command.hoon   # Server command mark (action + actor)
  mar/notes/response.hoon  # Response mark (for watch paths)
  mar/notes/update.hoon    # Durable update mark
  desk.bill                # Agent manifest (just %notes)
  desk.docket-0            # App metadata (title, color, site path, version)
  sys.kelvin               # Kelvin version
```

There's also a companion macOS menubar app at `app/src-tauri/` (Tauri v2). See `.github/workflows/desktop-app.yml` for the release pipeline — push a tag like `app-v0.1.0` to build a universal `.dmg` and draft a GitHub Release.

## UI Workflow (Critical)

The agent imports the UI core at compile time:

```hoon
/=  ui  /lib/notes-ui
```

`lib/notes-ui.hoon` is a `|%` core with arms `++index`, `++manifest`, `++service-worker`, `++favicon-svg`, `++icon-svg`. The agent references them as `index:ui`, `manifest:ui`, etc.

**`app/notes-ui/index.html` is NOT what the browser sees.** The served HTML comes from the `++index` arm in `lib/notes-ui.hoon`. The two must stay in sync — regenerate the lib after every edit.

### Edit → Sync → Deploy workflow

1. Edit `desk/app/notes-ui/index.html` (the working copy)
2. Regenerate the `++index` arm in `desk/lib/notes-ui.hoon`:
   ```sh
   ./scripts/build-notes-ui.sh
   ```
   The script splices the index.html content into the `++index` arm and leaves the static-asset arms (manifest, sw, icons) untouched. To edit those, hand-edit `desk/lib/notes-ui.hoon`.
3. Bump `++dummy` in `desk/app/notes.hoon` to force a recompile:
   ```hoon
   ++  dummy  'describe-your-change-v1'
   ```
4. Rsync to the dev ship and commit:
   ```sh
   rsync -avL desk/ ~/sidwyn-nimnev-nocsyx-lassul/notes/
   ```
   **Do NOT use `--delete`** — rsync without delete to avoid wiping ship-side files.
5. Commit via MCP:
   ```
   mcp__sidwyn__commit-desk  desk=notes
   ```
6. Hard-refresh the browser (Cmd+Shift+R) to see changes.

### Important: triple-quote safety

`lib/notes-ui.hoon` wraps each asset in a Hoon triple-quoted cord (`'''`). If the index.html ever contains `'''` the build will break — `build-notes-ui.sh` will refuse to run in that case.

## Dev Ship

The default dev ship for `%notes` is `~sidwyn-nimnev-nocsyx-lassul` (mounted at `~/sidwyn-nimnev-nocsyx-lassul/notes/`). Use the sidwyn MCP tools (`mcp__sidwyn__*`) to commit, poke, scry, and run tests. Other moons (bospur, simtyc) host different work streams — do not touch them unless explicitly directed.

## Agent Architecture

### State

Current state is `state-10:notes`:

```
+$  state-10
  $:  %10
      books=(map flag [=net =notebook-state])
      next-id=@ud
      published=(map [=flag note-id=@ud] @t)
      invites=(map flag invite-info)
  ==
```

- `books` — map of notebook flag → `[net notebook-state]`. `net` discriminates `%pub` (we host) vs `%sub` (we subscribe).
- `next-id` — single counter on this ship for all locally-created notebooks / folders / notes (remote notebooks bring foreign IDs).
- `published` — compound-keyed on `[flag note-id]` so per-notebook note-id collisions don't clobber each other.
- `invites` — pending invites we've received from other ships.

`flag` is `[=ship name=@tas]`. New flags are slugified at create time: title `"My Notes!"` + nid 42 → `'my-notes-42'`.

Each `notebook-state` contains `notebook` (the metadata record), `members`, `visibility`, `folders`, `notes`, and `history` (per-note revision archive).

Migrations follow the tlon-style linear pattern: a `|^` kelt with one `++state-N-to-N+1` arm per version step. The `+$ any-state` head-tagged union and the `=?` chain in `+load` walk forward from whatever version is on disk to state-10.

### API Surface

**Scry paths** (all prefixed with `/v0/`, all return typed marks under `mar/notes/`):
- `/v0/notebooks` — list of notebook-summary `{flag, notebook, visibility}` (mark `%notes-notebooks`)
- `/v0/notebook/~ship/name` — notebook-detail `{flag, notebook}` (mark `%notes-notebook`)
- `/v0/folders/~ship/name` — `(list folder)` (mark `%notes-folders`)
- `/v0/folder/~ship/name/<id>` — single folder (mark `%notes-folder`)
- `/v0/notes/~ship/name` — `(list note)` (mark `%notes-notes`)
- `/v0/note/~ship/name/<id>` — single note (mark `%notes-note`)
- `/v0/note-history/~ship/name/<id>` — `(list note-revision)` (mark `%notes-note-history`)
- `/v0/members/~ship/name` — `(list member-record)` (mark `%notes-members`)
- `/v0/invites` — `(list invite-record)` (mark `%notes-invites`)
- `/v0/published` — `(list published-record)` (mark `%notes-published`)

Each mark has both a `++json` grow arm (Eyre `.json` requests) and a `++noun` grow arm. Per-notebook peeks are routed through `++no-peek` inside `no-core` after `++no-abed` loads the notebook context. Cross-cutting peeks (`/v0/notebooks`, `/v0/published`, `/v0/invites`) stay at the top level.

**Poke marks**:
- `%notes-action` (a-notes) — local actions from our own UI. `+poke %notes-action` asserts `=(our.bowl src.bowl)`. The handler routes notebook-scoped actions through `++no-action`, which builds a c-notes command and pokes the host (which may be us — Gall loops self-pokes back through `+poke %notes-command`).
- `%notes-command` (c-notes) — cross-ship commands. Two arms: `%notify-invite` (host pushing a pending invite to an invitee) and `%notebook` (subscriber forwarding a notebook-scoped command to the host). The host's `%notebook` arm dispatches to `se-poke` inside `se-core`.

Action types (`a-notes` in `sur/notes.hoon`):
- Top-level: `%create-notebook`, `%join`, `%leave`, `%accept-invite`, `%decline-invite`, `%notebook`
- Notebook-scoped (a-notebook): `%rename`, `%delete`, `%visibility`, `%invite`, `%create-folder`, `%folder`, `%create-note`, `%note`, `%batch-import`, `%batch-import-tree`
- Note-scoped (a-note): `%rename`, `%move`, `%delete`, `%update` (with `expected-revision`), `%publish`, `%unpublish`, `%restore`

`%publish` / `%unpublish` are local-only (don't propagate as c-notes commands) — they manipulate the local `published` map cache.

**Watch paths**:
- `/v0/notes/~ship/name/stream` — local UI subscription (snapshot + updates) — handled by `++no-watch`
- `/v0/notes/~ship/name/updates` — host-side path other ships watch to receive log updates — handled by `++se-watch`
- `/v0/inbox/stream` — top-level inbox events (invite received / removed / notebooks-changed)

**HTTP routes** (served under `/notes`):
- `/notes/manifest.json`, `/notes/sw.js`, `/notes/icon.svg`, `/notes/favicon.svg` — PWA static assets
- `/notes/pub/~host/name/<noteId>` — serve a published note's stored HTML
- `/notes/share/~ship/name` — share-redirect page
- Anything else under `/notes/*` — serve the UI `index`

HTTP dispatch lives in `++serve-http`.

### Notebook flag

Notebooks are identified by a "flag" `[=ship name=@tas]`. Formatted as `~host/name` in URLs and scry paths. The name is a slugified `@tas` term (e.g. `'my-notes-42'`). The flag is the stable identity across ships.

### Visibility

`%private` (default) rejects `%join` from ships that aren't already in `members`. `%public` accepts any join. Only the owner can toggle via `%visibility`.

## Frontend Architecture

The UI is a single HTML file with inline CSS and JS. No build step, no framework.

### Routing

URL scheme: `/notes/nb/<host>/<flagName>[/f/<folderId>][/n/<noteId>]`.

- Every selection change (notebook / folder / note) pushes a new URL via `pushRoute()`.
- `popstate` (browser back/forward) calls `applyRoute()` which re-hydrates state to match the URL.
- Deep-link refresh works because the agent serves the UI for any `/notes/*` that isn't a `/notes/pub/...` URL, and `applyRoute` rehydrates from scry.
- A synchronous IIFE at the top of the script sets `data-view` on `.layout` before first paint so mobile doesn't flash the wrong slide panel on load.

### Layout (3-column desktop, slide-panel mobile)

Desktop:
- **Left sidebar**: notebooks list + add/import/desktop-sync actions + brand/version. Collapsible via a toggle button; widths persist to `localStorage`.
- **Middle column**: file-browser-style list — folders and notes interleaved. Header has back/up/label, action buttons (gear, +folder, +note) on the right.
- **Right editor**: markdown editor with preview toggle, save status, rev indicator.
- 3px drag handles between columns (`rgba(124,106,247,0.4)` on hover). Widths persisted in `localStorage`.

Mobile:
- Three-panel slide navigation via `data-view` attribute on `.layout` (`notebooks` / `notes` / `editor`).
- In-app back buttons navigate via URL so browser back/forward + refresh stay in sync.
- Sidebar actions (add notebook / import / desktop sync) collapse into a hamburger in the brand row; tap expands the existing `.sidebar-actions` cluster above the brand.
- Notebook actions (gear / +folder / +note) move to a contextual bottom footer (`.notes-panel-footer`) via a small JS reparent on resize.
- Gear menu opens upward and left-aligns with the button on mobile.

### Icons

Inline SVG sprite defined right after `<body>`. Icons are referenced via `<svg class="icon"><use href="#i-name"/></svg>`. The JS helper `icon('name')` returns the SVG markup for use in render functions.

Available: `notebook`, `folder`, `doc`, `folder-plus`, `doc-plus`, `plus`, `arrow-up`, `download`, `folder-down`, `eye`, `ellipsis`, `globe`, `gear`, `lock`, `sidebar`, `chevron-right`, `sync`, `menu`.

`.icon` has `opacity: 0.65` by default; `.icon-btn:hover .icon` bumps to `0.95`.

### Key state variables (JS)

- `activeNotebookId` / `activeNotebookFlag` — selected notebook
- `activeFolderId` — current folder (set to root folder id when notebook selected)
- `activeNoteId` — note open in editor
- `notebooks`, `folders`, `notes` — client-side caches loaded via scry
- `publishedIds` — Set of `pubKey(flag, noteId)` strings for quick lookup
- `dirty`, `savedRevision`, `saving`, `autoCreating`, `conflictActive` — editor state machine

### Rendering

- `renderNotebooks()` — sidebar notebook list (shows lock on private notebooks)
- `renderItems()` — combined folder+notes list in the middle column (date + body preview under note titles)
- `updateHeader()` — middle column header (folder/notebook name, up button, action visibility)

Navigation: `navigateToFolder(id)` / `folderUp()`.

### Editor behavior

- **Auto-save**: editor/title input triggers a 1.5s debounced `autoSave()`. Uses `expectedRevision` for conflict detection. Ctrl/Cmd+S force-saves.
- **Auto-create on type**: if the user starts typing with no note selected, `triggerAutoCreate()` pokes `create-note` and the typed content is preserved and promoted into the new note when it lands.
- **Conflict banner**: if a remote `note-updated` arrives while `dirty`, or `autoSave` fails and a re-scry shows the remote rev ahead, a banner shows above the editor with "Keep mine" (adopt remote rev + re-save) or "Use remote" (discard local, reload). `conflictActive = true` blocks auto-save until resolved.
- **Revision display**: the editor toolbar has a `rev N` label that stays in sync with `savedRevision`.

### Alpha disclaimer

First load shows a modal-locked disclaimer warning about alpha data-loss risk. Acknowledgement persists in `localStorage['alpha-disclaimer-acknowledged']`.

### Eyre Channel

The UI creates an Eyre channel for subscriptions. It subscribes to the active notebook's stream and handles snapshot/update events to keep the UI in sync. `setConnectionState("connected" | "reconnecting" | "disconnected")` updates the sidebar section label (amber for reconnecting, danger for disconnected).

### Keyboard shortcuts

- `Ctrl/Cmd+S` — force-save
- `Ctrl/Cmd+Alt+N` — new note (regular `Cmd+N` is reserved by browsers)
