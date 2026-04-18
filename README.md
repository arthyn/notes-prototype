# %notes — Urbit Notebook Agent

A prototype Urbit-native writing app. Shared notebooks with plain Markdown, folder organization, and a built-in editor UI served directly from the agent.

**Spec:** [SPEC.md](SPEC.md)

## What it does

- **Notebook CRUD** — create, rename, delete notebooks with membership and roles (owner/editor/viewer)
- **Public / private visibility** — notebooks default to private; a private notebook rejects `%join` requests from non-members
- **Shared notebooks across ships** — host/subscriber model with per-notebook join/leave; each notebook is addressed by a flag (`~host-ship/name`)
- **Folder hierarchy** — nested folders within notebooks; tap a folder to navigate in
- **Markdown notes** — plain Markdown body, revision-tracked, with auto-save + conflict detection
- **Conflict banner** — when a remote edit lands while you're dirty (or the save is rejected), a banner offers "Keep mine" / "Use remote"
- **Publish to web** — publish a rendered note at `/notes/pub/~host/name/<id>` (per-notebook scoped URL); toggle on/off per note
- **Batch import** — flat file import or recursive folder-tree import (uses `webkitdirectory`)
- **Notebook export** — dump a notebook to a `.zip` of `.md` files preserving the folder tree; no external deps (inline zip encoder)
- **Markdown preview** — inline parser with headings, bold/italic, code blocks, lists, tables, links, images
- **Routable UI** — `/notes/nb/<host>/<name>[/f/<fid>][/n/<nid>]` — browser back/forward, refresh, and deep links all work
- **Resizable + collapsible columns** — 3px drag handles with persisted widths; sidebar collapses via a toggle button
- **Mobile-friendly** — three-panel slide navigation, larger tap targets, contextual bottom footer per screen, hamburger for sidebar actions
- **JSON API** — full HTTP access via eyre (pokes + scries)
- **SSE subscriptions** — real-time event stream for UI sync
- **Desktop sync companion** — Tauri macOS menubar app (`app/src-tauri`) mirrors notes to a folder of `.md` files (builds via `.github/workflows/desktop-app.yml`)
- **Self-hosted UI** — HTML served directly from the agent at `/notes`

## Status

This is an **alpha prototype** — the backend + UI loop works end-to-end on Urbit, multi-ship sharing works, but expect bugs and possible data loss. Keep backups of anything irreplaceable.

The roadmap in [SPEC.md](SPEC.md#editor--ui-roadmap) tracks planned polish and features (wiki-links/backlinks, search, quick switcher, editor font controls, zen mode, light mode, Landscape theme integration, folder rename/delete, formatting shortcuts).

## Install

Requires a running Urbit ship on kelvin 409/410.

```
|merge %notes our %base
```

Copy the desk contents into your `%notes` desk, then:

```
|commit %notes
|install our %notes
```

The UI will be available at `http://localhost:8080/notes` (adjust port to your ship's eyre binding).

## API

### Pokes (via eyre channel)

Mark: `notes-action` (JSON). Optional `_flag` field on any action routes it to a specific notebook (prevents id collisions across ships).

Notebook-level:
```json
{"create-notebook": "My Notebook"}
{"rename-notebook": {"notebookId": 1, "title": "New"}}
{"delete-notebook": {"notebookId": 1}}
{"set-visibility": {"notebookId": 1, "visibility": "public"}}
{"join": {"notebookId": 1}}
{"leave": {"notebookId": 1}}
{"join-remote": {"ship": "~sampel", "name": "book"}}
{"leave-remote": {"ship": "~sampel", "name": "book"}}
```

Folder:
```json
{"create-folder": {"notebookId": 1, "parentFolderId": null, "name": "Chapter 1"}}
{"rename-folder": {"notebookId": 1, "folderId": 2, "name": "New"}}
{"move-folder": {"notebookId": 1, "folderId": 2, "newParentFolderId": 5}}
{"delete-folder": {"notebookId": 1, "folderId": 2, "recursive": true}}
```

Note:
```json
{"create-note": {"notebookId": 1, "folderId": 2, "title": "Intro", "bodyMd": "# Hello"}}
{"update-note": {"notebookId": 1, "noteId": 3, "bodyMd": "# Updated", "expectedRevision": 0}}
{"rename-note": {"notebookId": 1, "noteId": 3, "title": "New Title"}}
{"move-note": {"noteId": 3, "notebookId": 1, "folderId": 4}}
{"delete-note": {"noteId": 3, "notebookId": 1}}
{"batch-import": {"notebookId": 1, "folderId": 2, "notes": [{"title": "Note", "bodyMd": "..."}]}}
{"batch-import-tree": {"notebookId": 1, "parentFolderId": 2, "tree": [...]}}
```

Publishing (host-only, not forwarded to remote hosts):
```json
{"publish-note": {"notebookId": 1, "noteId": 3, "html": "<article>...</article>"}}
{"unpublish-note": {"notebookId": 1, "noteId": 3}}
```

### Scries (via `/~/scry/notes/`)

```
/v0/notebooks.json                    — all notebooks (includes visibility)
/v0/notebook/<ship>/<name>.json       — single notebook
/v0/folders/<ship>/<name>.json        — folders in notebook
/v0/notes/<ship>/<name>.json          — notes in notebook
/v0/members/<ship>/<name>.json        — members of notebook
/v0/published.json                    — list of {host, flagName, noteId}
```

### Subscriptions

Subscribe to `/v0/notes/<ship>/<name>/stream` for real-time UI updates:
- `notebook-created`, `notebook-renamed`, `notebook-deleted`, `notebook-visibility-changed`
- `folder-created`, `folder-renamed`, `folder-moved`, `folder-deleted`
- `note-created`, `note-updated`, `note-renamed`, `note-moved`, `note-deleted`
- `member-joined`, `member-left`

Remote subscribers watch `/v0/notes/<ship>/<name>/updates` for replication.

### Published notes (HTTP)

Published notes are served as standalone HTML at:

```
/notes/pub/~host-ship/<name>/<noteId>
```

## Desk Structure

```
app/notes.hoon             — Gall agent (eyre binding, HTTP handler, SSE, state migrations)
app/notes-ui/index.html    — source HTML for the UI (working copy — edit here)
sur/notes.hoon             — types (notebook, folder, note, visibility, state-0..4)
lib/notes-json.hoon        — JSON encoding/decoding
lib/notes-ui.hoon          — generated cord of index.html (what the agent actually serves)
mar/notes/action.hoon      — client action mark
mar/notes/command.hoon     — server command mark
mar/notes/update.hoon      — canonical update mark
mar/notes/response.hoon    — client response mark
mar/json.hoon              — JSON mark with mime grow arm
mar/html.hoon              — HTML mark
desk.bill                  — agent manifest
desk.docket-0              — app metadata
sys.kelvin                 — kelvin 409/410
```

See [AGENTS.md](AGENTS.md) for the development workflow (editing the UI, the `++dummy` recompile trick, syncing to a moon).

## License

MIT
