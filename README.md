# %notes — Urbit Notebook Agent

A prototype Urbit-native writing app. Shared notebooks with plain Markdown, folder organization, and a built-in editor UI served directly from the agent.

**Spec:** [~/depths/tlon/notebook/spec.md](https://github.com/arthyn/notes-prototype/blob/master/SPEC.md) (working name in spec: *%scribe*)

## What it does

- **Notebook CRUD** — create, rename notebooks with membership and roles (owner/editor/viewer)
- **Folder hierarchy** — nested folders within notebooks
- **Markdown notes** — plain Markdown body, revision-tracked, with optimistic conflict detection
- **Batch import** — flat file import or recursive folder tree import (supports `webkitdirectory` browser API)
- **Markdown preview** — inline parser with headings, bold/italic, code blocks, lists, tables, links, images
- **JSON API** — full HTTP access via eyre (pokes + scries)
- **SSE subscriptions** — real-time event stream for UI sync
- **Self-hosted UI** — HTML served directly from the agent at `/notes`

## Status

This is a **prototype** — a vertical slice proving the backend + UI loop works on Urbit. It implements the core of the [spec](SPEC.md) (M1 + M2 milestones) but is missing:

- Wiki-links and backlinks (M4)
- Export (M5)
- Multi-ship collaboration (currently single-ship only)
- Autosave / conflict merge UI
- Proper glob-based frontend

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

Mark: `notes-action` (JSON)

```json
{"create-notebook": "My Notebook"}
{"create-folder": {"notebookId": 1, "parentFolderId": null, "name": "Chapter 1"}}
{"create-note": {"notebookId": 1, "folderId": 2, "title": "Intro", "bodyMd": "# Hello"}}
{"update-note": {"noteId": 3, "bodyMd": "# Updated", "expectedRevision": 0}}
{"rename-note": {"notebookId": 1, "noteId": 3, "title": "New Title"}}
{"move-note": {"noteId": 3, "notebookId": 1, "folderId": 4}}
{"delete-note": {"noteId": 3, "notebookId": 1}}
{"batch-import": {"notebookId": 1, "folderId": 2, "notes": [{"title": "Note", "bodyMd": "..."}]}}
```

### Scries (via `/~/scry/notes/`)

```
/v0/notebooks.json                  — all notebooks
/v0/notebook/<ship>/<name>.json     — single notebook
/v0/folders/<ship>/<name>.json      — folders in notebook
/v0/notes/<ship>/<name>.json        — notes in notebook
/v0/members/<ship>/<name>.json      — members of notebook
```

### Subscriptions

Subscribe to `/v0/notes/<ship>/<name>/stream` for real-time UI updates:
- `notebook-created`, `notebook-renamed`
- `folder-created`, `folder-renamed`, `folder-moved`, `folder-deleted`
- `note-created`, `note-updated`, `note-renamed`, `note-moved`, `note-deleted`
- `member-joined`, `member-left`

Remote subscribers watch `/v0/notes/<ship>/<name>/updates` for replication.

## Desk Structure

```
app/notes.hoon           — Gall agent (eyre binding, HTTP handler, SSE)
app/notes-ui/index.html  — source HTML for the UI
sur/notes.hoon           — types (notebook, folder, note, a/c/u/r, state)
lib/notes-json.hoon      — JSON encoding/decoding
lib/notes-ui.hoon        — HTML as hex literal (Ford import workaround for kelvin 409)
mar/notes-action.hoon    — local action mark
mar/notes-command.hoon   — server command mark
mar/notes-update.hoon    — canonical update mark
mar/notes-response.hoon  — client response mark
mar/json.hoon            — JSON mark with mime grow arm
mar/html.hoon            — HTML mark
desk.bill                — agent manifest
sys.kelvin               — kelvin 409/410
```

## License

MIT
