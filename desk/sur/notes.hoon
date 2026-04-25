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
+$  notebook
  $:  id=@ud
      title=@t
      created-by=ship
      created-at=@da
      updated-at=@da
  ==
::
+$  folder
  $:  id=@ud
      notebook-id=@ud
      name=@t
      parent-folder-id=(unit @ud)
      created-by=ship
      created-at=@da
      updated-at=@da
  ==
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
+$  import-node
  $%  [%folder name=@t children=(list import-node)]
      [%note title=@t body-md=@t]
  ==
::
::  flag: global notebook identity (ship + name)
+$  flag  [=ship name=@t]
::
::  notebook-state: all data for a single notebook
+$  notebook-state
  $:  =notebook
      =notebook-members
      folders=(map @ud folder)
      notes=(map @ud note)
  ==
::
::  log: time-ordered append-only update log
+$  log    ((mop time u-notes) lte)
++  log-on  ((on time u-notes) lte)
::
::  net: host vs subscriber discriminator
+$  net
  $~  [%pub *log]
  $%  [%pub =log]
      [%sub =time init=_|]
  ==
::
::  ACUR
+$  a-notes
  $%  [%create-notebook title=@t]
      [%rename-notebook notebook-id=@ud title=@t]
      [%delete-notebook notebook-id=@ud]
      [%set-visibility notebook-id=@ud =visibility]
      [%invite notebook-id=@ud who=ship]
      [%send-invite notebook-id=@ud who=ship]
      [%notify-invite =flag title=@t]
      [%accept-invite =flag]
      [%decline-invite =flag]
      [%join notebook-id=@ud]
      [%leave notebook-id=@ud]
      [%join-remote =flag]
      [%leave-remote =flag]
      [%create-folder notebook-id=@ud parent-folder-id=(unit @ud) name=@t]
      [%rename-folder notebook-id=@ud folder-id=@ud name=@t]
      [%move-folder notebook-id=@ud folder-id=@ud new-parent-folder-id=@ud]
      [%delete-folder notebook-id=@ud folder-id=@ud recursive=?]
      [%create-note notebook-id=@ud folder-id=@ud title=@t body-md=@t]
      [%rename-note notebook-id=@ud note-id=@ud title=@t]
      [%move-note note-id=@ud notebook-id=@ud folder-id=@ud]
      [%delete-note note-id=@ud notebook-id=@ud]
      [%update-note notebook-id=@ud note-id=@ud body-md=@t expected-revision=@ud]
      [%batch-import notebook-id=@ud folder-id=@ud notes=(list [title=@t body-md=@t])]
      $:  %batch-import-tree
          notebook-id=@ud
          parent-folder-id=@ud
          tree=(list import-node)
      ==
      [%publish-note notebook-id=@ud note-id=@ud html=@t]
      [%unpublish-note notebook-id=@ud note-id=@ud]
  ==
::
+$  c-notes
  $%  [%create-notebook title=@t actor=ship]
      [%rename-notebook notebook-id=@ud title=@t actor=ship]
      [%delete-notebook notebook-id=@ud actor=ship]
      [%set-visibility notebook-id=@ud =visibility actor=ship]
      [%invite notebook-id=@ud who=ship actor=ship]
      [%send-invite notebook-id=@ud who=ship actor=ship]
      [%notify-invite =flag title=@t actor=ship]
      [%accept-invite =flag actor=ship]
      [%decline-invite =flag actor=ship]
      [%join notebook-id=@ud actor=ship]
      [%leave notebook-id=@ud actor=ship]
      [%join-remote =flag actor=ship]
      [%leave-remote =flag actor=ship]
      [%create-folder notebook-id=@ud parent-folder-id=(unit @ud) name=@t actor=ship]
      [%rename-folder notebook-id=@ud folder-id=@ud name=@t actor=ship]
      [%move-folder notebook-id=@ud folder-id=@ud new-parent-folder-id=@ud actor=ship]
      [%delete-folder notebook-id=@ud folder-id=@ud recursive=? actor=ship]
      [%create-note notebook-id=@ud folder-id=@ud title=@t body-md=@t actor=ship]
      [%rename-note notebook-id=@ud note-id=@ud title=@t actor=ship]
      [%move-note note-id=@ud notebook-id=@ud folder-id=@ud actor=ship]
      [%delete-note note-id=@ud notebook-id=@ud actor=ship]
      [%update-note notebook-id=@ud note-id=@ud body-md=@t expected-revision=@ud actor=ship]
      [%batch-import notebook-id=@ud folder-id=@ud notes=(list [title=@t body-md=@t]) actor=ship]
      $:  %batch-import-tree
          notebook-id=@ud
          parent-folder-id=@ud
          tree=(list import-node)
          actor=ship
      ==
  ==
::
::  u-notes: updates carry full data so subscribers can replay the log
+$  u-notes
  $%  [%notebook-created =notebook actor=ship]
      [%notebook-renamed notebook-id=@ud title=@t actor=ship]
      [%notebook-deleted notebook-id=@ud actor=ship]
      [%notebook-visibility-changed notebook-id=@ud =visibility actor=ship]
      [%member-joined notebook-id=@ud who=ship role=role actor=ship]
      [%member-left notebook-id=@ud who=ship actor=ship]
      [%folder-created =folder actor=ship]
      [%folder-renamed folder-id=@ud notebook-id=@ud name=@t actor=ship]
      [%folder-moved folder-id=@ud notebook-id=@ud new-parent-folder-id=@ud actor=ship]
      [%folder-deleted folder-id=@ud notebook-id=@ud actor=ship]
      [%note-created =note actor=ship]
      [%note-renamed note-id=@ud notebook-id=@ud title=@t actor=ship]
      [%note-moved note-id=@ud notebook-id=@ud folder-id=@ud actor=ship]
      [%note-deleted note-id=@ud notebook-id=@ud actor=ship]
      [%note-updated =note actor=ship]
      ::  These two are kept for binary compatibility with on-disk state
      ::  written by an earlier v6 build that widened u-notes. They are no
      ::  longer emitted at runtime (inbox events go out as raw JSON), and
      ::  must keep their on-disk shape (no title) — title is only carried
      ::  on the actually-emitted JSON, not in the dead u-notes variant.
      [%invite-received =flag from=ship sent-at=@da]
      [%invite-removed =flag]
  ==
::
+$  r-notes
  $%  [%update =time =u-notes]
      [%snapshot =flag =notebook-state]
  ==
::
::  type aliases
+$  action    a-notes
+$  command   c-notes
+$  update    u-notes
+$  response  r-notes
+$  event     u-notes
::  routed-action: action with optional explicit flag for routing
::  avoids notebook-id collisions across ships
+$  routed-action  [target=(unit flag) =action]
::
::  state-0: legacy single-player state (kept for migration)
::  updates uses * to avoid type-checking old event shapes
+$  state-0
  $:  %0
      notebooks=(map @ud notebook)
      folders=(map @ud folder)
      notes=(map @ud note)
      members=(map @ud notebook-members)
      next-id=@ud
      updates=*
      next-update-id=@ud
  ==
::
::  state-1: dual-mode host/subscriber state
+$  state-1
  $:  %1
      books=(map flag [=net =notebook-state])
      next-id=@ud
  ==
::
::  state-2: adds published notes cache keyed only by note-id
::  (kept for migration — the bare @ud key collides across notebooks)
+$  state-2
  $:  %2
      books=(map flag [=net =notebook-state])
      next-id=@ud
      published=(map @ud @t)
  ==
::
::  state-3: published keyed by (flag, note-id) to disambiguate across notebooks
+$  state-3
  $:  %3
      books=(map flag [=net =notebook-state])
      next-id=@ud
      published=(map [=flag note-id=@ud] @t)
  ==
::
::  state-4: adds per-notebook visibility (private default)
+$  state-4
  $:  %4
      books=(map flag [=net =notebook-state])
      next-id=@ud
      published=(map [=flag note-id=@ud] @t)
      visibilities=(map flag visibility)
  ==
::
::  state-5: pending invites with shape [from sent-at] — kept for migration
+$  invite-info-5  [from=ship sent-at=@da]
+$  state-5
  $:  %5
      books=(map flag [=net =notebook-state])
      next-id=@ud
      published=(map [=flag note-id=@ud] @t)
      visibilities=(map flag visibility)
      invites=(map flag invite-info-5)
  ==
::
::  state-6: invites carry the notebook title so the recipient sees a name,
::  not just a numeric flag, before they accept.
+$  invite-info  [from=ship sent-at=@da title=@t]
+$  state-6
  $:  %6
      books=(map flag [=net =notebook-state])
      next-id=@ud
      published=(map [=flag note-id=@ud] @t)
      visibilities=(map flag visibility)
      invites=(map flag invite-info)
  ==
::
+$  state  state-6
--
