# Notes Agent Development Guide

## Overview

`%notes` is an Urbit Gall agent for collaborative markdown notebooks. The frontend is a single-file HTML/CSS/JS app served inline from Hoon. See `SPEC.md` for the full product spec.

## Desk Structure

```
desk/
  app/notes.hoon          # Gall agent (state, pokes, peeks, watches)
  app/notes-ui/index.html # Working copy of the UI (source of truth for edits)
  sur/notes.hoon           # Type definitions (state, actions, commands, updates)
  lib/notes-json.hoon      # JSON encoding/decoding for all types
  lib/notes-ui.hoon        # Generated file — the UI served to the browser
  mar/notes/action.hoon    # Client action mark
  mar/notes/command.hoon   # Server command mark (action + actor)
  mar/notes/response.hoon  # Response mark (for watch paths)
  mar/notes/update.hoon    # Durable update mark
  desk.bill                # Agent manifest (just %notes)
  desk.docket-0            # App metadata (title, color, site path)
  sys.kelvin               # Kelvin version
```

## UI Workflow (Critical)

The agent imports the UI as a cord at compile time:

```hoon
/=  index  /lib/notes-ui
```

**This means `app/notes-ui/index.html` is NOT what the browser sees.** The served HTML comes from `lib/notes-ui.hoon`. These two files must stay in sync.

### Edit → Sync → Deploy workflow

1. Edit `desk/app/notes-ui/index.html` (the working copy)
2. Generate the hoon lib wrapper:
   ```sh
   { printf "^-  @t\n'''\n"; cat desk/app/notes-ui/index.html; printf "'''\n"; } > desk/lib/notes-ui.hoon
   ```
3. Bump `++dummy` in `desk/app/notes.hoon` to force a recompile (the agent won't pick up UI changes unless the hoon source changes):
   ```hoon
   ++  dummy  'describe-your-change-v1'
   ```
4. Rsync to the dev ship and commit:
   ```sh
   rsync -avL desk/ ~/bospur-davmyl-nocsyx-lassul/notes/
   ```
   **Do NOT use `--delete`** — rsync without delete to avoid wiping ship-side files.
5. Build and commit via MCP (bospur):
   ```
   mcp__bospur__build-file  desk=notes  path=/app/notes/hoon
   mcp__bospur__commit-desk  desk=notes
   ```
6. Hard-refresh the browser (Cmd+Shift+R) to see changes.

### Important: triple-quote safety

`lib/notes-ui.hoon` wraps the HTML in a Hoon triple-quoted cord (`'''`). If the HTML ever contains `'''` the build will break. Grep for it before generating.

## Dev Ship

The dev moon is `~bospur-davmyl-nocsyx-lassul`. It has a `%notes` desk mounted at `~/bospur-davmyl-nocsyx-lassul/notes/`. Use the bospur MCP tools to build, commit, poke, and scry the agent.

## Agent Architecture

### State

The agent state (`state-1:notes`) contains:
- `notebooks`: map of notebook-id to notebook
- `folders`: map of folder-id to folder
- `notes`: map of note-id to note
- `next-id`: auto-incrementing ID counter

Each notebook has a root folder (`name="/"`). Notes belong to folders via `folder-id`.

### API Surface

**Scry paths** (all prefixed with `/v0/`):
- `/v0/notebooks` — list all notebooks
- `/v0/folders/~ship/name` — folders for a notebook (by flag)
- `/v0/notes/~ship/name` — notes for a notebook (by flag)

**Poke mark**: `%notes-action` with JSON body. Key actions:
- `create-notebook`, `create-folder`, `create-note`
- `update-note` (with `expectedRevision` for conflict detection)
- `rename-note`, `delete-note`, `delete-folder`
- `batch-import`, `batch-import-tree`

**Watch path**: `/v0/notes/~ship/name/stream` — SSE stream of updates.

### Notebook flag

Notebooks are identified by a "flag" string: `~host-ship/notebook-name`. This is used in scry paths and subscription paths.

## Frontend Architecture

The UI is a single HTML file with inline CSS and JS. No build step, no framework.

### Layout (3-column)

- **Left sidebar (220px)**: Notebook list + import buttons at bottom
- **Middle column (280px)**: Interleaved file-browser-style list — folders and notes in one scrollable list. Click a folder to navigate into it, click a note to open it.
- **Right panel (flex)**: Markdown editor with preview toggle

### Icons

Uses an inline SVG sprite defined at the top of `<body>`. Icons are referenced via `<svg class="icon"><use href="#i-name"/></svg>`. The JS helper `icon('name')` returns the SVG markup for use in render functions.

Available icons: `notebook`, `folder`, `doc`, `folder-plus`, `doc-plus`, `plus`, `arrow-up`, `download`, `folder-down`, `eye`, `ellipsis`.

### Key state variables

- `activeNotebookId` / `activeNotebookFlag` — selected notebook
- `activeFolderId` — current folder being viewed (always set to root folder when notebook selected)
- `activeNoteId` — note open in editor
- `notebooks`, `folders`, `notes` — client-side data caches (loaded via scry)

### Rendering

- `renderNotebooks()` — sidebar notebook list
- `renderItems()` — combined folder+notes list in the middle column
- `updateHeader()` — middle column header (folder name, up button, action buttons)

Navigation is folder-based: `navigateToFolder(id)` / `folderUp()`.

### Auto-save

Editor input triggers a 1.5s debounced `autoSave()`. Uses `expectedRevision` for conflict detection. Ctrl/Cmd+S force-saves.

### Mobile

Three-panel slide navigation via `data-view` attribute on `.layout`:
- `notebooks` → sidebar
- `notes` → middle column (folders + notes)
- `editor` → editor panel

### Eyre Channel

The UI creates an Eyre channel for subscriptions. It subscribes to the active notebook's stream and handles snapshot/update events to keep the UI in sync.
