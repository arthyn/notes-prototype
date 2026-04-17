# Notes Integration Spec — Tlon Client

## Overview

Integrate `%notes` into the Tlon mobile/web client as a channel type within groups AND as a standalone entry point for solo notebooks. The Tlon client is a React Native monorepo at `github.com/tloncorp/tlon-apps`.

Tlon already has a `notebook` channel type backed by `%diary`. We add `%notes` as either a replacement or a parallel option — this spec assumes we're adding it alongside as a new type to avoid disrupting existing diary channels.

---

## Tlon Codebase Overview

**Monorepo structure:**
- `apps/tlon-mobile/` — React Native mobile app
- `apps/tlon-web/` — Web client  
- `packages/app/` — Shared app logic (navigation, features, UI)
- `packages/api/` — API types, Urbit bridge, channel config
- `packages/shared/` — Database, stores, actions
- `packages/ui/` — UI component library
- `desk/` — Urbit backend agents (Hoon)

**Key architectural patterns:**
- Channel types are a discriminated union: `'chat' | 'notebook' | 'gallery' | 'dm' | 'groupDm'`
- Each channel type has three registered components: **collection renderer**, **content renderer**, **draft input**
- Configuration is driven by `ChannelContentConfiguration` stored in channel metadata
- Urbit backend uses "kinds": `%chat`, `%diary`, `%heap` — mapped to client types via `getChannelKindFromType()`

---

## Implementation Plan

### Step 1: Add Channel Type

**File: `packages/api/src/types/models.ts` (line 46)**

Add `'urbit-notes'` to the `ChannelType` union:

```typescript
type ChannelType = 'chat' | 'notebook' | 'gallery' | 'dm' | 'groupDm' | 'urbit-notes';
```

**File: `packages/api/src/urbit/utils.ts` (lines 146-158)**

Add kind mapping. Since `%notes` is a separate Gall agent (not part of `%channels`), the kind mapping needs special handling:

```typescript
export function getChannelKindFromType(type: ChannelType): ChannelKind {
  switch (type) {
    case 'chat': return 'chat';
    case 'gallery': return 'heap';
    case 'notebook': return 'diary';
    case 'urbit-notes': return 'notes';  // new — maps to %notes agent
    default: return 'chat';
  }
}
```

### Step 2: Create WebView-Based Channel Components

Unlike chat/gallery/notebook which render natively, `urbit-notes` uses a WebView that loads the notes web UI from the ship.

**New file: `packages/app/ui/components/NotesChannel/NotesWebView.tsx`**

```tsx
import React, { useCallback } from 'react';
import { WebView } from 'react-native-webview';
import { useShipInfo } from '../../contexts/ship';

interface NotesWebViewProps {
  notebookFlag?: string;  // e.g. "~sampel-palnet/1"
  hideHeader?: boolean;
}

export function NotesWebView({ notebookFlag, hideHeader }: NotesWebViewProps) {
  const shipInfo = useShipInfo();
  
  if (!shipInfo?.shipUrl) return null;
  
  const params = new URLSearchParams();
  if (notebookFlag) params.set('notebook', notebookFlag);
  if (hideHeader) params.set('embed', '1');
  
  const url = `${shipInfo.shipUrl}/notes${params.toString() ? '?' + params.toString() : ''}`;

  return (
    <WebView
      source={{ uri: url }}
      sharedCookiesEnabled={true}
      thirdPartyCookiesEnabled={true}
      javaScriptEnabled={true}
      domStorageEnabled={true}
      style={{ flex: 1 }}
      // Keep navigation inside the WebView
      onShouldStartLoadWithRequest={(request) => {
        return request.url.startsWith(shipInfo.shipUrl!);
      }}
    />
  );
}
```

**New file: `packages/app/ui/components/NotesChannel/NotesPostCollection.tsx`**

The "collection renderer" that Tlon's channel system expects. Instead of rendering a native list of posts, it renders the full notes WebView:

```tsx
import React from 'react';
import { NotesWebView } from './NotesWebView';

interface NotesPostCollectionProps {
  channel: {
    id: string;
    // Channel ID format for notes: "notes/~host/name"
    // Extract the flag from the ID
  };
}

export function NotesPostCollection({ channel }: NotesPostCollectionProps) {
  // Extract notebook flag from channel ID
  // Channel ID format: "notes/~host-ship/notebook-name"
  const parts = channel.id.split('/');
  const notebookFlag = parts.length >= 3 ? `${parts[1]}/${parts[2]}` : undefined;
  
  return (
    <NotesWebView 
      notebookFlag={notebookFlag}
      hideHeader={true}
    />
  );
}
```

**New file: `packages/app/ui/components/NotesChannel/NotesDraftInput.tsx`**

A minimal or empty draft input since the WebView handles editing:

```tsx
import React from 'react';
import { View } from 'react-native';

// Notes editing happens inside the WebView, so no native draft input needed
export function NotesDraftInput() {
  return <View />;
}
```

### Step 3: Register Components

**File: `packages/api/src/client/channelContentConfig.ts`**

Add renderer IDs to the registries:

```typescript
// In allCollectionRenderers (line ~45)
{
  id: CollectionRendererId.notes,
  label: 'Notes',
  description: 'Collaborative markdown notebooks',
  // ...
}

// In allContentRenderers (line ~148)  
{
  id: PostContentRendererId.notes,
  label: 'Note',
  // ...
}

// In allDraftInputs (line ~115)
{
  id: DraftInputId.notes,
  label: 'Notes',
  // ...
}
```

**File: `packages/app/ui/contexts/componentsKits/ComponentsKitProvider.tsx`**

Register the components:

```typescript
// In collectionRenderers (line ~30)
[CollectionRendererId.notes]: NotesPostCollection,

// In contentRenderers (line ~43)
[PostContentRendererId.notes]: NotesPostContent, // or a passthrough

// In draftInputs (line ~67)
[DraftInputId.notes]: NotesDraftInput,
```

**File: `packages/app/ui/components/PostCollectionView.tsx`**

Add to the collection renderer switch.

### Step 4: Channel Creation

**File: `packages/app/ui/components/ManageChannels/CreateChannelSheet.tsx` (lines 50-69)**

Add "Notes" as an option in the channel creation dialog:

```typescript
{
  title: 'Notes',
  subtitle: 'Collaborative markdown notebooks with folders',
  type: 'urbit-notes' as ChannelType,
}
```

**File: `packages/shared/src/store/channelActions.ts`**

The `createChannel()` function needs to handle `urbit-notes` differently from other types. Instead of creating a channel via the `%channels` agent, it:

1. Pokes `%notes` agent with `create-notebook`
2. Stores the notebook flag as channel metadata

```typescript
async function createNotesChannel(groupId: string, title: string) {
  // Poke %notes agent to create the notebook
  await api.poke({
    app: 'notes',
    mark: 'notes-action',
    json: { 'create-notebook': title }
  });
  
  // Scry to get the new notebook's flag
  const notebooks = await api.scry({
    app: 'notes',
    path: '/v0/notebooks'
  });
  const nb = notebooks.find(n => n.notebook.title === title);
  const flag = `${nb.host}/${nb.flagName}`;
  
  // Create a channel entry in the group
  // The channel ID encodes the notes agent + flag: "notes/~host/name"
  await createChannelInGroup(groupId, {
    type: 'urbit-notes',
    title,
    id: `notes/${flag}`,
    metadata: { notebookFlag: flag }
  });
}
```

### Step 5: Group Join Flow

When a member opens a notes channel for the first time, their ship needs to join the remote notebook:

```typescript
async function openNotesChannel(channel: Channel) {
  const flag = channel.metadata?.notebookFlag;
  if (!flag) return;
  
  // Check if already joined by scrying local notebooks
  const notebooks = await api.scry({ app: 'notes', path: '/v0/notebooks' });
  const alreadyJoined = notebooks.some(n => `${n.host}/${n.flagName}` === flag);
  
  if (!alreadyJoined) {
    // Parse the flag to get ship + name
    const [ship, name] = flag.split('/');
    await api.poke({
      app: 'notes',
      mark: 'notes-action',
      json: { 'join-remote': { ship, name } }
    });
  }
}
```

---

## Web UI Changes for Embed Mode

The notes web UI needs to support being loaded inside the Tlon WebView. Add query parameter handling:

### `?notebook=~ship/name` — Auto-select a notebook

After connecting, if this param is present:
- Auto-select the specified notebook
- Hide the sidebar (single-notebook mode)
- If the notebook isn't joined yet, trigger `join-remote` automatically

### `?embed=1` — Embed mode

When embed mode is active:
- Hide the connect panel (use current origin + shared cookie)
- Hide the header bar (Tlon provides its own)
- Adjust padding for mobile viewport

**Implementation in `desk/app/notes-ui/index.html`:**

```javascript
// In the init section, after connect():
const params = new URLSearchParams(window.location.search);

if (params.has('embed')) {
  // Auto-connect using current origin
  document.getElementById("ship-url-input").value = window.location.origin;
  document.getElementById("connect-panel").style.display = "none";
  await connect();
}

if (params.has('notebook')) {
  const flag = params.get('notebook');
  // Wait for notebooks to load, then auto-select
  const nb = Object.values(notebooks).find(n => n.flag === flag);
  if (nb) {
    await selectNotebook(nb.id);
    document.querySelector('.sidebar').style.display = 'none';
  } else {
    // Not joined yet — join first
    const [ship, name] = flag.split('/');
    await pokeAction({ 'join-remote': { ship, name } });
    // Reload notebooks after join propagates
    setTimeout(async () => {
      await loadNotebooks();
      const nb = Object.values(notebooks).find(n => n.flag === flag);
      if (nb) {
        await selectNotebook(nb.id);
        document.querySelector('.sidebar').style.display = 'none';
      }
    }, 3000);
  }
}
```

---

## Standalone Notes Screen

For accessing solo notebooks outside of groups:

**New file: `packages/app/features/top/NotesScreen.tsx`**

```tsx
import React from 'react';
import { NotesWebView } from '../../ui/components/NotesChannel/NotesWebView';

export function NotesScreen() {
  // No notebookFlag = show full UI with sidebar and all notebooks
  return <NotesWebView />;
}
```

**Navigation registration in `packages/app/navigation/RootStack.tsx`:**

```tsx
<Stack.Screen 
  name="Notes" 
  component={NotesScreen}
  options={{ headerTitle: 'Notes' }}
/>
```

**Entry point** — add to the main screen or settings/profile area. The exact placement depends on the current nav structure. Options:

- Add to `ChatListScreen.tsx` as a floating button or list entry
- Add to the profile/settings section
- Add as a tab in the bottom navigation (if there's room)

---

## Database Schema Changes

**File: `packages/shared/src/db/schema.ts`**

The `channels` table already supports arbitrary `type` values. No schema change needed — just use `type: 'urbit-notes'` when creating channel entries.

The `contentConfiguration` field can store the notes-specific config:

```typescript
contentConfiguration: JSON.stringify({
  defaultPostCollectionRenderer: 'notes',
  defaultPostContentRenderer: 'notes', 
  draftInput: 'notes',
})
```

---

## Summary of Files to Modify

### New files:
- `packages/app/ui/components/NotesChannel/NotesWebView.tsx`
- `packages/app/ui/components/NotesChannel/NotesPostCollection.tsx`
- `packages/app/ui/components/NotesChannel/NotesDraftInput.tsx`
- `packages/app/features/top/NotesScreen.tsx`

### Modified files:
- `packages/api/src/types/models.ts` — Add `'urbit-notes'` to ChannelType
- `packages/api/src/urbit/utils.ts` — Add kind mapping
- `packages/api/src/client/channelContentConfig.ts` — Register renderers
- `packages/app/ui/contexts/componentsKits/ComponentsKitProvider.tsx` — Register components
- `packages/app/ui/components/PostCollectionView.tsx` — Add collection case
- `packages/app/ui/components/ManageChannels/CreateChannelSheet.tsx` — Add create option
- `packages/shared/src/store/channelActions.ts` — Handle notes channel creation
- `packages/app/navigation/RootStack.tsx` — Add NotesScreen route
- `desk/app/notes-ui/index.html` — Add embed mode + query param support

### No changes needed:
- `packages/shared/src/db/schema.ts` — Existing schema works
- `%notes` Gall agent — Already has all needed endpoints
- Auth system — Cookie sharing via WebView works
