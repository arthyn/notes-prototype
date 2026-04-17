::  lib/notes-json: JSON encoding/decoding for notes types
::
/-  notes
|%
::  +da-to-unix: convert @da to unix seconds
++  da-to-unix
  |=  da=@da
  ^-  @ud
  (div (sub da ~1970.1.1) ~s1)
::
::  +enjs: encode notes types to JSON
++  enjs
  =,  enjs:format
  |%
  ++  notebook
    |=  nb=notebook:notes
    ^-  json
    %-  pairs
    :~  ['id' (numb id.nb)]
        ['title' s+title.nb]
        ['createdBy' s+(scot %p created-by.nb)]
        ['createdAt' (numb (da-to-unix created-at.nb))]
        ['updatedAt' (numb (da-to-unix updated-at.nb))]
    ==
  ::
  ++  folder
    |=  fld=folder:notes
    ^-  json
    %-  pairs
    :~  ['id' (numb id.fld)]
        ['notebookId' (numb notebook-id.fld)]
        ['name' s+name.fld]
        ['parentFolderId' ?~(parent-folder-id.fld ~ (numb u.parent-folder-id.fld))]
        ['createdBy' s+(scot %p created-by.fld)]
        ['createdAt' (numb (da-to-unix created-at.fld))]
        ['updatedAt' (numb (da-to-unix updated-at.fld))]
    ==
  ::
  ++  note
    |=  nt=note:notes
    ^-  json
    %-  pairs
    :~  ['id' (numb id.nt)]
        ['notebookId' (numb notebook-id.nt)]
        ['folderId' (numb folder-id.nt)]
        ['title' s+title.nt]
        ['slug' ?~(slug.nt ~ s+u.slug.nt)]
        ['bodyMd' s+body-md.nt]
        ['createdBy' s+(scot %p created-by.nt)]
        ['createdAt' (numb (da-to-unix created-at.nt))]
        ['updatedBy' s+(scot %p updated-by.nt)]
        ['updatedAt' (numb (da-to-unix updated-at.nt))]
        ['revision' (numb revision.nt)]
    ==
  ::
  ++  event
    |=  evt=event:notes
    ^-  json
    %-  pairs
    ?-  -.evt
        %notebook-created
      :~  ['type' s+'notebook-created']
          ['notebookId' (numb id.notebook.evt)]
          ['notebook' (notebook notebook.evt)]
          ['actor' s+(scot %p actor.evt)]
      ==
        %notebook-renamed
      :~  ['type' s+'notebook-renamed']
          ['notebookId' (numb notebook-id.evt)]
          ['title' s+title.evt]
          ['actor' s+(scot %p actor.evt)]
      ==
        %member-joined
      :~  ['type' s+'member-joined']
          ['notebookId' (numb notebook-id.evt)]
          ['who' s+(scot %p who.evt)]
          ['actor' s+(scot %p actor.evt)]
      ==
        %member-left
      :~  ['type' s+'member-left']
          ['notebookId' (numb notebook-id.evt)]
          ['who' s+(scot %p who.evt)]
          ['actor' s+(scot %p actor.evt)]
      ==
        %folder-created
      :~  ['type' s+'folder-created']
          ['folderId' (numb id.folder.evt)]
          ['notebookId' (numb notebook-id.folder.evt)]
          ['folder' (folder folder.evt)]
          ['actor' s+(scot %p actor.evt)]
      ==
        %folder-renamed
      :~  ['type' s+'folder-renamed']
          ['folderId' (numb folder-id.evt)]
          ['notebookId' (numb notebook-id.evt)]
          ['name' s+name.evt]
          ['actor' s+(scot %p actor.evt)]
      ==
        %folder-moved
      :~  ['type' s+'folder-moved']
          ['folderId' (numb folder-id.evt)]
          ['notebookId' (numb notebook-id.evt)]
          ['newParentFolderId' (numb new-parent-folder-id.evt)]
          ['actor' s+(scot %p actor.evt)]
      ==
        %folder-deleted
      :~  ['type' s+'folder-deleted']
          ['folderId' (numb folder-id.evt)]
          ['notebookId' (numb notebook-id.evt)]
          ['actor' s+(scot %p actor.evt)]
      ==
        %note-created
      :~  ['type' s+'note-created']
          ['noteId' (numb id.note.evt)]
          ['notebookId' (numb notebook-id.note.evt)]
          ['note' (note note.evt)]
          ['actor' s+(scot %p actor.evt)]
      ==
        %note-renamed
      :~  ['type' s+'note-renamed']
          ['noteId' (numb note-id.evt)]
          ['notebookId' (numb notebook-id.evt)]
          ['title' s+title.evt]
          ['actor' s+(scot %p actor.evt)]
      ==
        %note-moved
      :~  ['type' s+'note-moved']
          ['noteId' (numb note-id.evt)]
          ['notebookId' (numb notebook-id.evt)]
          ['folderId' (numb folder-id.evt)]
          ['actor' s+(scot %p actor.evt)]
      ==
        %note-deleted
      :~  ['type' s+'note-deleted']
          ['noteId' (numb note-id.evt)]
          ['notebookId' (numb notebook-id.evt)]
          ['actor' s+(scot %p actor.evt)]
      ==
        %note-updated
      :~  ['type' s+'note-updated']
          ['noteId' (numb id.note.evt)]
          ['notebookId' (numb notebook-id.note.evt)]
          ['revision' (numb revision.note.evt)]
          ['note' (note note.evt)]
          ['actor' s+(scot %p actor.evt)]
      ==
    ==
  ::
  ++  response
    |=  res=response:notes
    ^-  json
    ?-  -.res
        %update
      %-  pairs
      :~  ['response' s+'update']
          ['update' (event u-notes.res)]
      ==
        %snapshot
      %-  pairs
      :~  ['response' s+'snapshot']
          ['host' s+(scot %p ship.flag.res)]
          ['flagName' s+name.flag.res]
      ==
    ==
  --
::
::  +dejs: decode JSON to notes types
++  dejs
  =,  dejs:format
  |%
  ::  +role: parse role string
  ++  role
    |=  jon=json
    ^-  role:notes
    ?>  ?=([%s *] jon)
    ?+  p.jon  ~|(%bad-role !!)
      %'owner'   %owner
      %'editor'  %editor
      %'viewer'  %viewer
    ==
  ::  +routed-action: parse action with optional _flag for routing
  ::  format: {"_flag": "~ship/name", "action-name": {fields...}}
  ++  routed-action
    |=  jon=json
    ^-  routed-action:notes
    ?>  ?=([%o *] jon)
    =/  flag-json=(unit json)  (~(get by p.jon) '_flag')
    =/  target=(unit flag:notes)
      ?~  flag-json  ~
      ?.  ?=([%s *] u.flag-json)  ~
      =/  raw=tape  (trip p.u.flag-json)
      =/  idx  (find "/" raw)
      ?~  idx  ~
      =/  ship-text=@t  (crip (scag u.idx raw))
      =/  name-text=@t  (crip (slag +(u.idx) raw))
      `[(slav %p ship-text) name-text]
    ::  remove _flag before parsing the action
    =/  clean=json  [%o (~(del by p.jon) '_flag')]
    [target (action clean)]
  ::
  ::  +action: parse action from JSON
  ::  format: {"action-name": {fields...}}
  ++  action
    |=  jon=json
    ^-  action:notes
    ?>  ?=([%o *] jon)
    =/  entries=(list [key=@t val=json])  ~(tap by p.jon)
    ?>  ?=(^ entries)
    =/  tag=@t  key.i.entries
    =/  val=json  val.i.entries
    ?+  tag  ~|(unknown-action+tag !!)
    ::
        %'create-notebook'
      [%create-notebook (so val)]
    ::
        %'rename-notebook'
      :-  %rename-notebook
      ((ot ~[['notebookId' ni] ['title' so]]) val)
    ::
        %'join'
      :-  %join
      ((ot ~[['notebookId' ni]]) val)
    ::
        %'leave'
      :-  %leave
      ((ot ~[['notebookId' ni]]) val)
    ::
        %'create-folder'
      :-  %create-folder
      ((ot ~[['notebookId' ni] ['parentFolderId' (mu ni)] ['name' so]]) val)
    ::
        %'rename-folder'
      :-  %rename-folder
      ((ot ~[['notebookId' ni] ['folderId' ni] ['name' so]]) val)
    ::
        %'move-folder'
      :-  %move-folder
      ((ot ~[['notebookId' ni] ['folderId' ni] ['newParentFolderId' ni]]) val)
    ::
        %'delete-folder'
      :-  %delete-folder
      ((ot ~[['notebookId' ni] ['folderId' ni] ['recursive' bo]]) val)
    ::
        %'create-note'
      :-  %create-note
      ((ot ~[['notebookId' ni] ['folderId' ni] ['title' so] ['bodyMd' so]]) val)
    ::
        %'rename-note'
      :-  %rename-note
      ((ot ~[['notebookId' ni] ['noteId' ni] ['title' so]]) val)
    ::
        %'move-note'
      :-  %move-note
      ((ot ~[['noteId' ni] ['notebookId' ni] ['folderId' ni]]) val)
    ::
        %'delete-note'
      :-  %delete-note
      ((ot ~[['noteId' ni] ['notebookId' ni]]) val)
    ::
        %'update-note'
      :-  %update-note
      ((ot ~[['notebookId' ni] ['noteId' ni] ['bodyMd' so] ['expectedRevision' ni]]) val)
    ::
        %'batch-import'
      :-  %batch-import
      =+  ^=  raw
        %.  val
        (ot ~[['notebookId' ni] ['folderId' ni] ['notes' (ar (ot ~[['title' so] ['bodyMd' so]]))]])
      raw
    ::
        %'batch-import-tree'
      :-  %batch-import-tree
      %.  val
      (ot ~[['notebookId' ni] ['parentFolderId' ni] ['tree' (ar import-node)]])
    ::
        %'join-remote'
      :-  %join-remote
      =/  raw  ((ot ~[['ship' (su ;~(pfix sig fed:ag))] ['name' so]]) val)
      [-.raw +.raw]
    ::
        %'leave-remote'
      :-  %leave-remote
      =/  raw  ((ot ~[['ship' (su ;~(pfix sig fed:ag))] ['name' so]]) val)
      [-.raw +.raw]
    ::
        %'publish-note'
      :-  %publish-note
      ((ot ~[['notebookId' ni] ['noteId' ni] ['html' so]]) val)
    ::
        %'unpublish-note'
      :-  %unpublish-note
      ((ot ~[['notebookId' ni] ['noteId' ni]]) val)
    ==
  ::
  ++  import-node
    |=  jon=json
    ^-  import-node:notes
    ?>  ?=([%o *] jon)
    ?:  (~(has by p.jon) 'children')
      :-  %folder
      ((ot ~[['name' so] ['children' (ar import-node)]]) jon)
    :-  %note
    ((ot ~[['title' so] ['bodyMd' so]]) jon)
  --
--
