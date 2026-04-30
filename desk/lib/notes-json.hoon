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
        ['updatedBy' s+(scot %p updated-by.nb)]
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
        ['updatedBy' s+(scot %p updated-by.fld)]
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
  ::  +note-revision: archived prior version of a note
  ++  note-revision
    |=  nr=note-revision:notes
    ^-  json
    %-  pairs
    :~  ['rev' (numb rev.nr)]
        ['at' (numb (da-to-unix at.nr))]
        ['author' s+(scot %p author.nr)]
        ['title' s+title.nr]
        ['bodyMd' s+body-md.nr]
    ==
  ::
  ::  +u-folder: encode a folder-scoped update
  ++  u-folder
    |=  [id=@ud upd=u-folder:notes]
    ^-  json
    ?-  -.upd
        %created
      %-  pairs
      :~  ['type' s+'folder-created']
          ['id' (numb id)]
          ['folder' (folder folder.upd)]
      ==
        %updated
      %-  pairs
      :~  ['type' s+'folder-updated']
          ['id' (numb id)]
          ['folder' (folder folder.upd)]
      ==
        %deleted
      %-  pairs
      :~  ['type' s+'folder-deleted']
          ['id' (numb id)]
      ==
    ==
  ::
  ::  +u-note: encode a note-scoped update
  ++  u-note
    |=  [id=@ud upd=u-note:notes]
    ^-  json
    ?-  -.upd
        %created
      %-  pairs
      :~  ['type' s+'note-created']
          ['id' (numb id)]
          ['note' (note note.upd)]
      ==
        %updated
      %-  pairs
      :~  ['type' s+'note-updated']
          ['id' (numb id)]
          ['note' (note note.upd)]
      ==
        %deleted
      %-  pairs
      :~  ['type' s+'note-deleted']
          ['id' (numb id)]
      ==
        %published
      %-  pairs
      :~  ['type' s+'note-published']
          ['id' (numb id)]
          ['html' s+html.upd]
      ==
        %unpublished
      %-  pairs
      :~  ['type' s+'note-unpublished']
          ['id' (numb id)]
      ==
        %history-archived
      %-  pairs
      :~  ['type' s+'note-history-archived']
          ['id' (numb id)]
          ['revision' (note-revision note-revision.upd)]
      ==
    ==
  ::
  ::  +u-notebook: encode a notebook-scoped update
  ++  u-notebook
    |=  [=flag:notes upd=u-notebook:notes]
    ^-  json
    %-  pairs
    ?-  -.upd
        %created
      :~  ['type' s+'notebook-created']
          ['host' s+(scot %p ship.flag)]
          ['flagName' s+name.flag]
          ['notebook' (notebook notebook.upd)]
          ['visibility' s+(scot %tas visibility.upd)]
      ==
        %updated
      :~  ['type' s+'notebook-updated']
          ['host' s+(scot %p ship.flag)]
          ['flagName' s+name.flag]
          ['notebook' (notebook notebook.upd)]
      ==
        %deleted
      :~  ['type' s+'notebook-deleted']
          ['host' s+(scot %p ship.flag)]
          ['flagName' s+name.flag]
      ==
        %visibility
      :~  ['type' s+'notebook-visibility-changed']
          ['host' s+(scot %p ship.flag)]
          ['flagName' s+name.flag]
          ['visibility' s+(scot %tas visibility.upd)]
      ==
        %member-joined
      :~  ['type' s+'member-joined']
          ['host' s+(scot %p ship.flag)]
          ['flagName' s+name.flag]
          ['who' s+(scot %p who.upd)]
          ['role' s+(scot %tas role.upd)]
      ==
        %member-left
      :~  ['type' s+'member-left']
          ['host' s+(scot %p ship.flag)]
          ['flagName' s+name.flag]
          ['who' s+(scot %p who.upd)]
      ==
        %invite-received
      :~  ['type' s+'invite-received']
          ['host' s+(scot %p ship.flag)]
          ['flagName' s+name.flag]
          ['from' s+(scot %p from.upd)]
          ['title' s+title.upd]
      ==
        %invite-removed
      :~  ['type' s+'invite-removed']
          ['host' s+(scot %p ship.flag)]
          ['flagName' s+name.flag]
      ==
        %folder
      :~  ['type' s+'folder-update']
          ['host' s+(scot %p ship.flag)]
          ['flagName' s+name.flag]
          ['folderUpdate' (u-folder id.upd u-folder.upd)]
      ==
        %note
      :~  ['type' s+'note-update']
          ['host' s+(scot %p ship.flag)]
          ['flagName' s+name.flag]
          ['noteUpdate' (u-note id.upd u-note.upd)]
      ==
    ==
  ::
  ::  +response: encode r-notes response
  ++  response
    |=  res=response:notes
    ^-  json
    ?-  -.res
        %update
      %-  pairs
      :~  ['type' s+'update']
          ['host' s+(scot %p ship.flag.res)]
          ['flagName' s+name.flag.res]
          ['time' (numb (da-to-unix time.update.res))]
          ['update' (u-notebook flag.res u-notebook.update.res)]
      ==
        %snapshot
      %-  pairs
      :~  ['type' s+'snapshot']
          ['host' s+(scot %p ship.flag.res)]
          ['flagName' s+name.flag.res]
          ['visibility' s+(scot %tas visibility.res)]
      ==
    ==
  --
::
::  +dejs: decode JSON to notes types
++  dejs
  =,  dejs:format
  |%
  ::  +get-type: extract "type" string from a JSON object
  ++  get-type
    |=  jon=json
    ^-  @t
    ?>  ?=([%o *] jon)
    =/  typ=(unit json)  (~(get by p.jon) 'type')
    ?>  ?=(^ typ)
    ?>  ?=([%s *] u.typ)
    p.u.typ
  ::
  ::  +a-folder: parse a-folder action object {type, ...fields}
  ++  a-folder
    |=  jon=json
    ^-  a-folder:notes
    ?>  ?=([%o *] jon)
    =/  tag=@t  (get-type jon)
    ?+  tag  ~|(unknown-a-folder+tag !!)
        %'rename'
      [%rename ((ot ~[['name' so]]) jon)]
        %'move'
      [%move ((ot ~[['newParent' ni]]) jon)]
        %'delete'
      [%delete ((ot ~[['recursive' bo]]) jon)]
    ==
  ::
  ::  +a-note: parse a-note action object {type, ...fields}
  ++  a-note
    |=  jon=json
    ^-  a-note:notes
    ?>  ?=([%o *] jon)
    =/  tag=@t  (get-type jon)
    ?+  tag  ~|(unknown-a-note+tag !!)
        %'rename'
      [%rename ((ot ~[['title' so]]) jon)]
        %'move'
      [%move ((ot ~[['folder' ni]]) jon)]
        %'delete'
      [%delete ~]
        %'update'
      :-  %update
      ((ot ~[['body' so] ['expectedRevision' ni]]) jon)
        %'publish'
      [%publish ((ot ~[['html' so]]) jon)]
        %'unpublish'
      [%unpublish ~]
        %'restore'
      [%restore ((ot ~[['rev' ni]]) jon)]
    ==
  ::
  ::  +a-notebook: parse a-notebook action object {type, ...fields}
  ++  a-notebook
    |=  jon=json
    ^-  a-notebook:notes
    ?>  ?=([%o *] jon)
    =/  tag=@t  (get-type jon)
    ?+  tag  ~|(unknown-a-notebook+tag !!)
        %'rename'
      [%rename ((ot ~[['title' so]]) jon)]
        %'delete'
      [%delete ~]
        %'visibility'
      =/  raw=@t  ((ot ~[['visibility' so]]) jon)
      ?.  ?|(=('public' raw) =('private' raw))
        ~|(bad-visibility+raw !!)
      [%visibility ?:(=('public' raw) %public %private)]
        %'invite'
      [%invite ((ot ~[['who' (su ;~(pfix sig fed:ag))]]) jon)]
        %'create-folder'
      :-  %create-folder
      ((ot ~[['parent' (mu ni)] ['name' so]]) jon)
        %'folder'
      :-  %folder
      ((ot ~[['id' ni] ['action' a-folder]]) jon)
        %'create-note'
      :-  %create-note
      ((ot ~[['folder' ni] ['title' so] ['body' so]]) jon)
        %'note'
      :-  %note
      ((ot ~[['id' ni] ['action' a-note]]) jon)
        %'batch-import'
      :-  %batch-import
      ((ot ~[['folder' ni] ['notes' (ar (ot ~[['title' so] ['body' so]]))]]) jon)
        %'batch-import-tree'
      :-  %batch-import-tree
      ((ot ~[['parent' ni] ['tree' (ar import-node)]]) jon)
    ==
  ::
  ::  +action: parse top-level a-notes from JSON
  ::  format: {"type": "...", ...fields}
  ++  action
    |=  jon=json
    ^-  action:notes
    ?>  ?=([%o *] jon)
    =/  tag=@t  (get-type jon)
    ?+  tag  ~|(unknown-action+tag !!)
        %'create-notebook'
      =/  title=(unit json)  (~(get by p.jon) 'title')
      ?>  ?=(^ title)
      [%create-notebook (so u.title)]
        %'join'
      :-  %join
      =/  raw  ((ot ~[['ship' (su ;~(pfix sig fed:ag))] ['name' so]]) jon)
      [-.raw +.raw]
        %'leave'
      :-  %leave
      =/  raw  ((ot ~[['ship' (su ;~(pfix sig fed:ag))] ['name' so]]) jon)
      [-.raw +.raw]
        %'accept-invite'
      :-  %accept-invite
      =/  raw  ((ot ~[['ship' (su ;~(pfix sig fed:ag))] ['name' so]]) jon)
      [-.raw +.raw]
        %'decline-invite'
      :-  %decline-invite
      =/  raw  ((ot ~[['ship' (su ;~(pfix sig fed:ag))] ['name' so]]) jon)
      [-.raw +.raw]
        %'notebook'
      :-  %notebook
      =/  flag-json=(unit json)  (~(get by p.jon) 'flag')
      =/  act-json=(unit json)   (~(get by p.jon) 'action')
      ?>  ?=(^ flag-json)
      ?>  ?=(^ act-json)
      =/  =flag:notes
        ?>  ?=([%s *] u.flag-json)
        =/  raw-tape=tape  (trip p.u.flag-json)
        =/  idx  (find "/" raw-tape)
        ?>  ?=(^ idx)
        =/  ship-text=@t  (crip (scag u.idx raw-tape))
        =/  name-text=@t  (crip (slag +(u.idx) raw-tape))
        [(slav %p ship-text) name-text]
      [flag (a-notebook u.act-json)]
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
    ((ot ~[['title' so] ['body' so]]) jon)
  --
--
