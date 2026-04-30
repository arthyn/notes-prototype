::  notes: shared notebook surface types
::
|%
+$  role
  ?(%owner %editor %viewer)
::
::  notebook visibility: private (default) rejects joins from non-members;
::  public allows anyone to join.
+$  visibility
  ?(%public %private)
::
::  $flag: global notebook identity (ship + name)
+$  flag  [=ship name=@t]
::
::  $notebook: top-level container
::
+$  notebook
  $:  id=@ud
      title=@t
      created-by=ship
      created-at=@da
      updated-at=@da
      updated-by=ship
  ==
::
::  $folder: directory node inside a notebook
::
+$  folder
  $:  id=@ud
      notebook-id=@ud
      name=@t
      parent-folder-id=(unit @ud)
      created-by=ship
      created-at=@da
      updated-at=@da
      updated-by=ship
  ==
::
::  $note: leaf document node
::
+$  note
  $:  id=@ud
      notebook-id=@ud
      folder-id=@ud
      title=@t
      slug=(unit @t)
      body-md=@t
      created-by=ship
      created-at=@da
      updated-by=ship
      updated-at=@da
      revision=@ud
  ==
::
+$  notebook-members  (map ship role)
::
::  $note-revision: an archived prior version of a note
+$  note-revision
  $:  rev=@ud
      at=@da
      author=ship
      title=@t
      body-md=@t
  ==
::
::  $invite-info: pending invite we've received
+$  invite-info  [from=ship sent-at=@da title=@t]
::
+$  import-node
  $%  [%folder name=@t children=(list import-node)]
      [%note title=@t body-md=@t]
  ==
::
::  $notebook-state: all data for a single notebook
+$  notebook-state
  $:  =notebook
      =notebook-members
      folders=(map @ud folder)
      notes=(map @ud note)
  ==
::
::  Actions (client → agent)
::  ============================================================
::
::  $a-notes: top-level client actions.
::  notebook-scoped actions are routed via [%notebook =flag =a-notebook].
::
+$  a-notes
  $%  [%create-notebook title=@t]
      [%join =flag]
      [%leave =flag]
      [%accept-invite =flag]
      [%decline-invite =flag]
      [%notebook =flag =a-notebook]
  ==
::
::  $a-notebook: actions scoped to a specific notebook.
::  Outer tag carries flag so inner tags drop the subject prefix.
::
+$  a-notebook
  $%  [%rename title=@t]
      [%delete ~]
      [%visibility =visibility]
      [%invite who=ship]
      [%create-folder parent=(unit @ud) name=@t]
      [%folder id=@ud =a-folder]
      [%create-note folder=@ud title=@t body=@t]
      [%note id=@ud =a-note]
      [%batch-import folder=@ud notes=(list [title=@t body=@t])]
      [%batch-import-tree parent=@ud tree=(list import-node)]
  ==
::
::  $a-folder: actions scoped to a specific folder
::
+$  a-folder
  $%  [%rename name=@t]
      [%move new-parent=@ud]
      [%delete recursive=?]
  ==
::
::  $a-note: actions scoped to a specific note
::
+$  a-note
  $%  [%rename title=@t]
      [%move folder=@ud]
      [%delete ~]
      [%update body=@t expected-revision=@ud]
      [%publish html=@t]
      [%unpublish ~]
      [%restore rev=@ud]
  ==
::
::  Commands (poke surface — actor authenticated via src.bowl)
::  ============================================================
::
::  $c-notes: tagged union of cross-ship messages.
::  %notify-invite — host pokes invitee with a pending invite (carries title
::    for inbox rendering pre-join). src.bowl must equal the host of `flag`.
::  %notebook — subscriber forwards a notebook-scoped command to the host.
::    src.bowl is the actor; permission checks happen in se-core.
::
+$  c-notes
  $%  [%notify-invite =flag title=@t]
      [%notebook =flag =c-notebook]
  ==
::
::  $c-cmd: internal shape used by se-poke and the per-arm handlers.
::  Conceptually `command for a specific notebook` — the flag carries
::  routing context, c-notebook carries the verb. Not a wire type;
::  c-notes %notebook arm peels into this on the way in.
::
+$  c-cmd  [=flag =c-notebook]
::
::  $c-notebook: notebook-scoped commands. Mirrors a-notebook minus
::  client-only verbs (%restore is purely client-side restatement of %update).
::  Adds %member-join/%member-leave for peer join/leave signals.
::
+$  c-notebook
  $%  [%rename title=@t]
      [%delete ~]
      [%visibility =visibility]
      [%invite who=ship]
      [%create-folder parent=(unit @ud) name=@t]
      [%folder id=@ud =a-folder]
      [%create-note folder=@ud title=@t body=@t]
      [%note id=@ud =a-note]
      [%batch-import folder=@ud notes=(list [title=@t body=@t])]
      [%batch-import-tree parent=@ud tree=(list import-node)]
      [%member-join ~]
      [%member-leave ~]
  ==
::
::  Updates (agent → subscriber)
::  ============================================================
::
+$  u-notebook
  $%  [%created =notebook =visibility]
      [%updated =notebook]
      [%deleted ~]
      [%visibility =visibility]
      [%member-joined who=ship =role]
      [%member-left who=ship]
      [%invite-received from=ship title=@t]
      [%invite-removed ~]
      [%folder id=@ud =u-folder]
      [%note id=@ud =u-note]
  ==
::
+$  u-folder
  $%  [%created =folder]
      [%updated =folder]
      [%deleted ~]
  ==
::
+$  u-note
  $%  [%created =note]
      [%updated =note]
      [%deleted ~]
      [%published html=@t]
      [%unpublished ~]
      [%history-archived =note-revision]
  ==
::
::  $update: single log entry — time-keyed u-notebook
+$  update  [=time =u-notebook]
::
::  $u-notes: wire/stream shape — carries flag so listeners know which notebook
+$  u-notes  [=flag =u-notebook]
::
::  Responses (subscription facts)
::  ============================================================
::
::  $r-notes: facts pushed to subscribers on /v0/notes/~ship/name/stream
::  %snapshot carries visibility so subscribers can seed their local cache.
::
+$  r-notes
  $%  [%snapshot =flag =visibility =notebook-state]
      [%update =flag =update]
  ==
::
::  $log: time-ordered append-only update log (one per notebook, u-notebook entries)
+$  log    ((mop time u-notebook) lte)
++  log-on  ((on time u-notebook) lte)
::
::  $net: host vs subscriber discriminator
+$  net
  $~  [%pub *log]
  $%  [%pub =log]
      [%sub =time init=_|]
  ==
::
::  Type aliases
+$  action    a-notes
+$  command   c-notes
+$  response  r-notes
::
::  Versioned state — newest first
::  ============================================================
::
::  state-8: current — nested ACUR types, u-notebook log, updated-by on entities
+$  state-8  ::  current
  $:  %8
      books=(map flag [=net =notebook-state])
      next-id=@ud
      published=(map [=flag note-id=@ud] @t)
      visibilities=(map flag visibility)
      invites=(map flag invite-info)
      history=(map [=flag note-id=@ud] (list note-revision))
  ==
::
+$  state  state-8
::
::  Legacy entity types — for migrating states 0-7 which lack updated-by
::  on notebook and folder.
::
+$  notebook-v0
  $:  id=@ud
      title=@t
      created-by=ship
      created-at=@da
      updated-at=@da
  ==
::
+$  folder-v0
  $:  id=@ud
      notebook-id=@ud
      name=@t
      parent-folder-id=(unit @ud)
      created-by=ship
      created-at=@da
      updated-at=@da
  ==
::
+$  notebook-state-v0
  $:  notebook=notebook-v0
      notebook-members=notebook-members
      folders=(map @ud folder-v0)
      notes=(map @ud note)
  ==
::
::  net-v0: old log used raw u-notes (flat), not u-notebook
+$  net-v0
  $%  [%pub log=*]
      [%sub =time init=_|]
  ==
::
::  invite-info-5: invite from state-5 (lacks title)
+$  invite-info-5  [from=ship sent-at=@da]
::
::  state-7: master current state (pre-refactor).
::  Uses net-v0 (log=*) since the on-disk log has u-notes entries (old flat type).
::  Uses notebook-state-v0 since notebook and folder lacked updated-by.
+$  state-7
  $:  %7
      books=(map flag [net=net-v0 notebook-state=notebook-state-v0])
      next-id=@ud
      published=(map [=flag note-id=@ud] @t)
      visibilities=(map flag visibility)
      invites=(map flag invite-info)
      history=(map [=flag note-id=@ud] (list note-revision))
  ==
::
::  state-6: invites carry notebook title.
::  Also uses v0 types for books.
+$  state-6
  $:  %6
      books=(map flag [net=net-v0 notebook-state=notebook-state-v0])
      next-id=@ud
      published=(map [=flag note-id=@ud] @t)
      visibilities=(map flag visibility)
      invites=(map flag invite-info)
  ==
::
::  state-5: pending invites with shape [from sent-at] — kept for migration
+$  state-5
  $:  %5
      books=(map flag [net=net-v0 notebook-state=notebook-state-v0])
      next-id=@ud
      published=(map [=flag note-id=@ud] @t)
      visibilities=(map flag visibility)
      invites=(map flag invite-info-5)
  ==
::
::  state-4: adds per-notebook visibility
+$  state-4
  $:  %4
      books=(map flag [net=net-v0 notebook-state=notebook-state-v0])
      next-id=@ud
      published=(map [=flag note-id=@ud] @t)
      visibilities=(map flag visibility)
  ==
::
::  state-3: published keyed by (flag, note-id)
+$  state-3
  $:  %3
      books=(map flag [net=net-v0 notebook-state=notebook-state-v0])
      next-id=@ud
      published=(map [=flag note-id=@ud] @t)
  ==
::
::  state-2: adds published notes cache keyed only by note-id
+$  state-2
  $:  %2
      books=(map flag [net=net-v0 notebook-state=notebook-state-v0])
      next-id=@ud
      published=(map @ud @t)
  ==
::
::  state-1: dual-mode host/subscriber state
+$  state-1
  $:  %1
      books=(map flag [net=net-v0 notebook-state=notebook-state-v0])
      next-id=@ud
  ==
::
::  state-0: legacy single-player state (kept for migration)
+$  state-0
  $:  %0
      notebooks=(map @ud notebook-v0)
      folders=(map @ud folder-v0)
      notes=(map @ud note)
      members=(map @ud notebook-members)
      next-id=@ud
      updates=*
      next-update-id=@ud
  ==
::
--
