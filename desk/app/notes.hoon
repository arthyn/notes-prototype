::  notes: shared notebook Gall agent
::
/-  notes
/+  default-agent, dbug, verb, notes-json
/=  index  /lib/notes-ui
|%
+$  card  card:agent:gall
+$  state-0  state-0:notes
::  raw-state: in-memory state without %0 tag
+$  raw-state
  $:  notebooks=(map @ud notebook:notes)
      folders=(map @ud folder:notes)
      notes=(map @ud note:notes)
      members=(map @ud notebook-members:notes)
      next-id=@ud
      updates=(map @ud u-notes:notes)
      next-update-id=@ud
  ==
--
=|  state=raw-state
%-  agent:dbug
%+  verb  |
^-  agent:gall
=<
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
++  on-init
  ^-  (quip card _this)
  :_  this
  :~  [%pass /eyre/notes %arvo %e %connect [~ /notes] %notes]
  ==
::
++  on-save
  ^-  vase
  !>([%0 state])
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =/  s=state-0:notes  !<(state-0:notes old)
  :_  this(state [notebooks.s folders.s notes.s members.s next-id.s updates.s next-update-id.s])
  :~  [%pass /eyre/notes %arvo %e %connect [~ /notes] %notes]
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  =^  cards  state  abet:(poke mark vase)
  [cards this]
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  ~
    ::  /x/ui - serve the frontend
      [%x %ui ~]
    ``html+!>(index)
    ::  /x/notebooks - list notebooks visible to caller
      [%x %notebooks ~]
    =/  nbs=(list json)
      %+  turn
        %+  murn  ~(tap by notebooks.state)
        |=  [nid=@ud nb=notebook:notes]
        ?:  (can-view nid src.bowl)
          `nb
        ~
      notebook:enjs:notes-json
    ``json+!>([%a nbs])
    ::  /x/notebook/<id> - get single notebook
      [%x %notebook @ ~]
    =/  nid=@ud  (slav %ud i.t.t.path)
    =/  nb=(unit notebook:notes)  (~(get by notebooks.state) nid)
    ?~  nb  ``json+!>(~)
    ?>  (can-view nid src.bowl)
    ``json+!>((notebook:enjs:notes-json u.nb))
    ::  /x/folders/<notebook-id> - list folders in notebook
      [%x %folders @ ~]
    =/  nid=@ud  (slav %ud i.t.t.path)
    ?>  (can-view nid src.bowl)
    =/  flds=(list json)
      %+  turn  (all-folders-in-notebook nid)
      folder:enjs:notes-json
    ``json+!>([%a flds])
    ::  /x/folder/<id> - get single folder
      [%x %folder @ ~]
    =/  fid=@ud  (slav %ud i.t.t.path)
    =/  fld=(unit folder:notes)  (~(get by folders.state) fid)
    ?~  fld  ``json+!>(~)
    ?>  (can-view notebook-id.u.fld src.bowl)
    ``json+!>((folder:enjs:notes-json u.fld))
    ::  /x/notes/<notebook-id> - list notes in notebook
      [%x %notes @ ~]
    =/  nid=@ud  (slav %ud i.t.t.path)
    ?>  (can-view nid src.bowl)
    =/  nts=(list json)
      %+  turn  (all-notes-in-notebook nid)
      note:enjs:notes-json
    ``json+!>([%a nts])
    ::  /x/notes/<notebook-id>/<folder-id> - list notes in folder
      [%x %notes @ @ ~]
    =/  nid=@ud  (slav %ud i.t.t.path)
    =/  fid=@ud  (slav %ud i.t.t.t.path)
    ?>  (can-view nid src.bowl)
    =/  fld=folder:notes  (need-folder fid)
    ?>  =(notebook-id.fld nid)
    =/  nts=(list json)
      %+  turn  (all-notes-in-folder fid)
      note:enjs:notes-json
    ``json+!>([%a nts])
    ::  /x/note/<id> - get single note
      [%x %note @ ~]
    =/  nid=@ud  (slav %ud i.t.t.path)
    =/  nt=(unit note:notes)  (~(get by notes.state) nid)
    ?~  nt  ``json+!>(~)
    ?>  (can-view notebook-id.u.nt src.bowl)
    ``json+!>((note:enjs:notes-json u.nt))
    ::  /x/v0/updates/<notebook-id>/<since-seq> - replay update stream
      [%x %v0 %updates @ @ ~]
    =/  nid=@ud  (slav %ud i.t.t.t.path)
    =/  since=@ud  (slav %ud i.t.t.t.t.path)
    ?>  (can-view nid src.bowl)
    =/  ups=(list json)
      %+  turn  (updates-since nid since)
      |=  [seq=@ud evt=u-notes:notes]
      %-  pairs:enjs:format
      :~  ['seq' (numb:enjs:format seq)]
          ['event' (event:enjs:notes-json evt)]
      ==
    ``json+!>([%a ups])
    ::  /x/members/<notebook-id> - get notebook members
      [%x %members @ ~]
    =/  nid=@ud  (slav %ud i.t.t.path)
    ?>  (can-view nid src.bowl)
    =/  mbrs=(unit notebook-members:notes)  (~(get by members.state) nid)
    ?~  mbrs  ``json+!>(~)
    =/  mlist=(list json)
      %+  turn  ~(tap by u.mbrs)
      |=  [who=ship r=role:notes]
      %-  pairs:enjs:format
      :~  ['ship' s+(scot %p who)]
          ['role' s+(scot %tas r)]
      ==
    ``json+!>([%a mlist])
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
      [%http-response *]
    `this
  ::
      [%v0 %events *]
    `this
  ::
      [%v0 %stream *]
    `this
  ==
::
++  on-agent  on-agent:def
++  on-arvo
  |=  [wir=wire sig=sign-arvo]
  ^-  (quip card _this)
  ?+  sig  (on-arvo:def wir sig)
    [%eyre %bound *]  `this
  ==
++  on-leave  on-leave:def
++  on-fail   on-fail:def
--
::  helper core
|_  [=bowl:gall cards=(list card)]
+*  this     +<
    no-core  this
    se-core  .
++  cor   .
++  abet
  ^-  [(list card) raw-state]
  [(flop cards) state]
++  emit  |=(=card cor(cards [card cards]))
++  emil  |=(caz=(list card) cor(cards (welp (flop caz) cards)))
++  no-core
  |_  no-act=a-notes:notes
  ++  no-core  .
  ++  no-abed
    |=  no-act=a-notes:notes
    ^+  no-core
    no-core(no-act no-act)
  ++  no-abet
    |=  c=_cor
    ^+  cor
    c
  ++  emit  emit:cor
  ++  emil  emil:cor
  ++  no-poke
    ^+  cor
    (no-poke:cor no-act)
  --
++  se-core
  |_  [se-act=a-notes:notes]
  ++  se-core  .
  ++  se-abed
    |=  se-act=a-notes:notes
    ^+  se-core
    se-core(se-act se-act)
  ++  se-abet
    |=  c=_cor
    ^+  cor
    c
  ++  emit  emit:cor
  ++  emil  emil:cor
  ++  se-poke
    ^+  cor
    (no-poke:cor se-act)
  --
++  poke
  |=  [=mark =vase]
  ^+  cor
  ?+  mark  !!
      %handle-http-request
    =/  req  !<([eyre-id=@ta =inbound-request:eyre] vase)
    =/  data=octs  [(met 3 index) index]
    =/  headers=(list [key=@t value=@t])
      :~  ['content-type' 'text/html']
      ==
    =/  =response-header:http  [200 headers]
    %-  emil
    :~  [%give %fact [/http-response/[eyre-id.req]]~ %http-response-header !>(response-header)]
        [%give %fact [/http-response/[eyre-id.req]]~ %http-response-data !>(`data)]
        [%give %kick [/http-response/[eyre-id.req]]~ ~]
    ==
  ::
      %notes-command
    =/  cmd=c-notes:notes
      !<(c-notes:notes vase)
    =/  act=a-notes:notes
      (command-to-action cmd)
    $(mark %notes-action, vase !>(act))
  ::
      %notes-action
    =/  no-act=a-notes:notes
      !<(a-notes:notes vase)
    =/  cmd=c-notes:notes
      (action-to-command no-act src.bowl)
    =/  act=a-notes:notes
      (command-to-action cmd)
    (no-poke act)
  ==
::
++  no-poke
  |=  act=a-notes:notes
  ^+  cor
  ?-  -.act
        %create-notebook
      ::  allocate notebook id and root folder id
      =/  nid=@ud  +(next-id.state)
      =/  rfid=@ud  +(nid)
      =/  mbrs=notebook-members:notes
        (~(put by *(map ship role:notes)) src.bowl %owner)
      =/  nb=notebook:notes
        [nid title.act src.bowl now.bowl now.bowl]
      =/  rf=folder:notes
        [rfid nid '/' ~ src.bowl now.bowl now.bowl]
      =/  next=raw-state
        %_  state
          notebooks  (~(put by notebooks.state) nid nb)
          folders    (~(put by folders.state) rfid rf)
          members    (~(put by members.state) nid mbrs)
          next-id    rfid
        ==
      =^  cards  state  abet:(commit-update next [%notebook-created nid src.bowl])
      this
    ::
        %rename-notebook
      =/  nb=notebook:notes  (need-notebook notebook-id.act)
      ?>  (is-owner notebook-id.act src.bowl)
      =/  new-nb=notebook:notes
        nb(title title.act, updated-at now.bowl)
      =/  next=raw-state
        state(notebooks (~(put by notebooks.state) notebook-id.act new-nb))
      =^  cards  state  abet:(commit-update next [%notebook-renamed notebook-id.act src.bowl])
      this
    ::
        %join
      =/  nb=notebook:notes  (need-notebook notebook-id.act)
      =/  mbrs=notebook-members:notes
        (~(gut by members.state) notebook-id.act *(map ship role:notes))
      =/  new-mbrs=notebook-members:notes
        (~(put by mbrs) src.bowl %editor)
      =/  next=raw-state
        state(members (~(put by members.state) notebook-id.act new-mbrs))
      =^  cards  state  abet:(commit-update next [%member-joined notebook-id.act src.bowl src.bowl])
      this
    ::
        %leave
      =/  nb=notebook:notes  (need-notebook notebook-id.act)
      =/  mbrs=notebook-members:notes
        (~(gut by members.state) notebook-id.act *(map ship role:notes))
      =/  new-mbrs=notebook-members:notes
        (~(del by mbrs) src.bowl)
      =/  next=raw-state
        state(members (~(put by members.state) notebook-id.act new-mbrs))
      =^  cards  state  abet:(commit-update next [%member-left notebook-id.act src.bowl src.bowl])
      this
    ::
        %create-folder
      =/  nb=notebook:notes  (need-notebook notebook-id.act)
      ?>  (can-edit notebook-id.act src.bowl)
      ::  validate parent if specified
      ?^  parent-folder-id.act
        =/  pf=folder:notes  (need-folder u.parent-folder-id.act)
        ?>  =(notebook-id.pf notebook-id.act)
        =/  fid=@ud  +(next-id.state)
        =/  nf=folder:notes
          [fid notebook-id.act name.act parent-folder-id.act src.bowl now.bowl now.bowl]
        =/  next=raw-state
          %_  state
            folders  (~(put by folders.state) fid nf)
            next-id  fid
          ==
        =^  cards  state  abet:(commit-update (touch-notebook next notebook-id.act) [%folder-created fid notebook-id.act src.bowl])
        this
      ::  parent is root (empty)
      =/  fid=@ud  +(next-id.state)
      =/  nf=folder:notes
        [fid notebook-id.act name.act ~ src.bowl now.bowl now.bowl]
      =/  next=raw-state
        %_  state
          folders  (~(put by folders.state) fid nf)
          next-id  fid
        ==
      =^  cards  state  abet:(commit-update (touch-notebook next notebook-id.act) [%folder-created fid notebook-id.act src.bowl])
      this
    ::
        %rename-folder
      =/  nb=notebook:notes  (need-notebook notebook-id.act)
      ?>  (can-edit notebook-id.act src.bowl)
      =/  fld=folder:notes  (need-folder folder-id.act)
      ?>  =(notebook-id.fld notebook-id.act)
      =/  new-fld=folder:notes
        fld(name name.act, updated-at now.bowl)
      =/  next=raw-state
        state(folders (~(put by folders.state) folder-id.act new-fld))
      =^  cards  state  abet:(commit-update (touch-notebook next notebook-id.act) [%folder-renamed folder-id.act notebook-id.act src.bowl])
      this
    ::
        %move-folder
      =/  nb=notebook:notes  (need-notebook notebook-id.act)
      ?>  (can-edit notebook-id.act src.bowl)
      =/  fld=folder:notes  (need-folder folder-id.act)
      ?>  =(notebook-id.fld notebook-id.act)
      =/  npf=folder:notes  (need-folder new-parent-folder-id.act)
      ?>  =(notebook-id.npf notebook-id.act)
      ::  cannot move folder into itself or its descendants
      =/  subtree=(set @ud)  (subtree-folder-ids folder-id.act)
      ?<  (~(has in subtree) new-parent-folder-id.act)
      =/  new-fld=folder:notes
        fld(parent-folder-id `new-parent-folder-id.act, updated-at now.bowl)
      =/  next=raw-state
        state(folders (~(put by folders.state) folder-id.act new-fld))
      =^  cards  state  abet:(commit-update (touch-notebook next notebook-id.act) [%folder-moved folder-id.act notebook-id.act src.bowl])
      this
    ::
        %delete-folder
      =/  nb=notebook:notes  (need-notebook notebook-id.act)
      ?>  (can-edit notebook-id.act src.bowl)
      =/  fld=folder:notes  (need-folder folder-id.act)
      ?>  =(notebook-id.fld notebook-id.act)
      ::  cannot delete root folder
      ?>  ?=(^ parent-folder-id.fld)
      ?:  recursive.act
        ::  delete folder and all children recursively
        =/  del-fids=(set @ud)  (subtree-folder-ids folder-id.act)
        =/  del-nids=(set @ud)  (note-ids-in-folder-set del-fids)
        =/  next=raw-state
          %_  state
            folders  (del-many-folders folders.state del-fids)
            notes    (del-many-notes notes.state del-nids)
          ==
        =^  cards  state  abet:(commit-update (touch-notebook next notebook-id.act) [%folder-deleted folder-id.act notebook-id.act src.bowl])
        this
      ::  non-recursive: fail if has children
      =/  children=(list @ud)  (folder-children-ids folder-id.act)
      ?>  =(~ children)
      =/  child-notes=(list note:notes)  (all-notes-in-folder folder-id.act)
      ?>  =(~ child-notes)
      =/  next=raw-state
        state(folders (~(del by folders.state) folder-id.act))
      =^  cards  state  abet:(commit-update (touch-notebook next notebook-id.act) [%folder-deleted folder-id.act notebook-id.act src.bowl])
      this
    ::
        %create-note
      =/  nb=notebook:notes  (need-notebook notebook-id.act)
      ?>  (can-edit notebook-id.act src.bowl)
      =/  fld=folder:notes  (need-folder folder-id.act)
      ?>  =(notebook-id.fld notebook-id.act)
      =/  nid=@ud  +(next-id.state)
      =/  nt=note:notes
        :*  nid
            notebook-id.act
            folder-id.act
            title.act
            ~
            body-md.act
            src.bowl
            now.bowl
            src.bowl
            now.bowl
            0
        ==
      =/  next=raw-state
        %_  state
          notes    (~(put by notes.state) nid nt)
          next-id  nid
        ==
      =^  cards  state  abet:(commit-update (touch-notebook next notebook-id.act) [%note-created nid notebook-id.act src.bowl])
      this
    ::
        %rename-note
      =/  nb=notebook:notes  (need-notebook notebook-id.act)
      ?>  (can-edit notebook-id.act src.bowl)
      =/  nt=note:notes  (need-note note-id.act)
      ?>  =(notebook-id.nt notebook-id.act)
      =/  new-nt=note:notes
        %_  nt
          title       title.act
          updated-by  src.bowl
          updated-at  now.bowl
          revision    +(revision.nt)
        ==
      =/  next=raw-state
        state(notes (~(put by notes.state) note-id.act new-nt))
      =^  cards  state  abet:(commit-update (touch-notebook next notebook-id.act) [%note-renamed note-id.act notebook-id.act src.bowl])
      this
    ::
        %move-note
      =/  nb=notebook:notes  (need-notebook notebook-id.act)
      ?>  (can-edit notebook-id.act src.bowl)
      =/  nt=note:notes  (need-note note-id.act)
      =/  fld=folder:notes  (need-folder folder-id.act)
      ?>  =(notebook-id.fld notebook-id.act)
      =/  old-nbid=@ud  notebook-id.nt
      =/  new-nt=note:notes
        %_  nt
          notebook-id  notebook-id.act
          folder-id    folder-id.act
          updated-by   src.bowl
          updated-at   now.bowl
          revision     +(revision.nt)
        ==
      =/  next=raw-state
        state(notes (~(put by notes.state) note-id.act new-nt))
      =/  next2=raw-state  (touch-notebook next notebook-id.act)
      =/  next3=raw-state
        ?:  =(old-nbid notebook-id.act)
          next2
        (touch-notebook next2 old-nbid)
      =^  cards  state  abet:(commit-update next3 [%note-moved note-id.act notebook-id.act folder-id.act src.bowl])
      this
    ::
        %delete-note
      =/  nb=notebook:notes  (need-notebook notebook-id.act)
      ?>  (can-edit notebook-id.act src.bowl)
      =/  nt=note:notes  (need-note note-id.act)
      ?>  =(notebook-id.nt notebook-id.act)
      =/  next=raw-state
        state(notes (~(del by notes.state) note-id.act))
      =^  cards  state  abet:(commit-update (touch-notebook next notebook-id.act) [%note-deleted note-id.act notebook-id.act src.bowl])
      this
    ::
        %update-note
      =/  nt=note:notes  (need-note note-id.act)
      ?>  (can-edit notebook-id.nt src.bowl)
      ::  optimistic concurrency check
      ?>  =(revision.nt expected-revision.act)
      =/  new-nt=note:notes
        %_  nt
          body-md     body-md.act
          updated-by  src.bowl
          updated-at  now.bowl
          revision    +(revision.nt)
        ==
      =/  next=raw-state
        state(notes (~(put by notes.state) note-id.act new-nt))
      =^  cards  state  abet:(commit-update (touch-notebook next notebook-id.nt) [%note-updated note-id.act notebook-id.nt revision.new-nt src.bowl])
      this
    ::
        %batch-import
      ?>  (can-edit notebook-id.act src.bowl)
      =/  items=(list [title=@t body-md=@t])  notes.act
      |-
      ?~  items
        this
      =/  nid=@ud  next-id.state
      =/  nt=note:notes
        :*  nid
            notebook-id.act
            folder-id.act
            title.i.items
            ~
            body-md.i.items
            src.bowl
            now.bowl
            src.bowl
            now.bowl
            0
        ==
      =.  state
        %_  state
          notes    (~(put by notes.state) nid nt)
          next-id  +(next-id.state)
        ==
      =.  state  (touch-notebook state notebook-id.act)
      =/  evt=u-notes:notes  [%note-created nid notebook-id.act src.bowl]
      =/  seq=@ud  +(next-update-id.state)
      =.  state
        %_  state
          updates          (~(put by updates.state) seq evt)
          next-update-id   seq
        ==
      =.  cards
        %+  weld  cards
        (event-cards seq evt)
      $(items t.items)
    ::
        %batch-import-tree
      ?>  (can-edit notebook-id.act src.bowl)
      =/  items=(list import-node:notes)  tree.act
      =|  stack=(list [remaining=(list import-node:notes) folder-id=@ud])
      =/  fid=@ud  parent-folder-id.act
      |-
      ?~  items
        ?~  stack
          this
        $(items remaining.i.stack, fid folder-id.i.stack, stack t.stack)
      ?-  -.i.items
          %note
        =/  nid=@ud  next-id.state
        =/  nt=note:notes
          :*  nid
              notebook-id.act
              fid
              title.i.items
              ~
              body-md.i.items
              src.bowl
              now.bowl
              src.bowl
              now.bowl
              0
          ==
        =.  state
          %_  state
            notes    (~(put by notes.state) nid nt)
            next-id  +(next-id.state)
          ==
        =/  evt=u-notes:notes  [%note-created nid notebook-id.act src.bowl]
        =/  seq=@ud  +(next-update-id.state)
        =.  state
          %_  state
            updates          (~(put by updates.state) seq evt)
            next-update-id   seq
          ==
        =.  cards
          %+  weld  cards
          (event-cards seq evt)
        $(items t.items)
      ::
          %folder
        =/  new-fid=@ud  next-id.state
        =/  nf=folder:notes
          [new-fid notebook-id.act name.i.items `fid src.bowl now.bowl now.bowl]
        =.  state
          %_  state
            folders  (~(put by folders.state) new-fid nf)
            next-id  +(next-id.state)
          ==
        =/  evt=u-notes:notes  [%folder-created new-fid notebook-id.act src.bowl]
        =/  seq=@ud  +(next-update-id.state)
        =.  state
          %_  state
            updates          (~(put by updates.state) seq evt)
            next-update-id   seq
          ==
        =.  cards
          %+  weld  cards
          (event-cards seq evt)
        ::  push current remaining onto stack, descend into children
        $(items children.i.items, stack [[t.items fid] stack], fid new-fid)
      ==
    ==
::
::
::  action-to-command: no-core local action to server command
++  action-to-command
  |=  [act=a-notes:notes actor=ship]
  ^-  c-notes:notes
  ?-  -.act
      %create-notebook      [%create-notebook title.act actor]
      %rename-notebook      [%rename-notebook notebook-id.act title.act actor]
      %join                 [%join notebook-id.act actor]
      %leave                [%leave notebook-id.act actor]
      %create-folder        [%create-folder notebook-id.act parent-folder-id.act name.act actor]
      %rename-folder        [%rename-folder notebook-id.act folder-id.act name.act actor]
      %move-folder          [%move-folder notebook-id.act folder-id.act new-parent-folder-id.act actor]
      %delete-folder        [%delete-folder notebook-id.act folder-id.act recursive.act actor]
      %create-note          [%create-note notebook-id.act folder-id.act title.act body-md.act actor]
      %rename-note          [%rename-note notebook-id.act note-id.act title.act actor]
      %move-note            [%move-note note-id.act notebook-id.act folder-id.act actor]
      %delete-note          [%delete-note note-id.act notebook-id.act actor]
      %update-note          [%update-note note-id.act body-md.act expected-revision.act actor]
      %batch-import         [%batch-import notebook-id.act folder-id.act notes.act actor]
      %batch-import-tree    [%batch-import-tree notebook-id.act parent-folder-id.act tree.act actor]
  ==
::
++  command-to-action
  |=  cmd=c-notes:notes
  ^-  a-notes:notes
  ?-  -.cmd
      %create-notebook      [%create-notebook title.cmd]
      %rename-notebook      [%rename-notebook notebook-id.cmd title.cmd]
      %join                 [%join notebook-id.cmd]
      %leave                [%leave notebook-id.cmd]
      %create-folder        [%create-folder notebook-id.cmd parent-folder-id.cmd name.cmd]
      %rename-folder        [%rename-folder notebook-id.cmd folder-id.cmd name.cmd]
      %move-folder          [%move-folder notebook-id.cmd folder-id.cmd new-parent-folder-id.cmd]
      %delete-folder        [%delete-folder notebook-id.cmd folder-id.cmd recursive.cmd]
      %create-note          [%create-note notebook-id.cmd folder-id.cmd title.cmd body-md.cmd]
      %rename-note          [%rename-note notebook-id.cmd note-id.cmd title.cmd]
      %move-note            [%move-note note-id.cmd notebook-id.cmd folder-id.cmd]
      %delete-note          [%delete-note note-id.cmd notebook-id.cmd]
      %update-note          [%update-note note-id.cmd body-md.cmd expected-revision.cmd]
      %batch-import         [%batch-import notebook-id.cmd folder-id.cmd notes.cmd]
      %batch-import-tree    [%batch-import-tree notebook-id.cmd parent-folder-id.cmd tree.cmd]
  ==
::  role-for: get role of ship in notebook, ~ if not member
++  role-for
  |=  [notebook-id=@ud who=ship]
  ^-  (unit role:notes)
  =/  mbrs=(unit notebook-members:notes)
    (~(get by members.state) notebook-id)
  ?~  mbrs  ~
  (~(get by u.mbrs) who)
::
::  can-view: check if ship can view notebook
++  can-view
  |=  [notebook-id=@ud who=ship]
  ^-  ?
  ?~  (role-for notebook-id who)  |
  &
::
::  can-edit: check if ship can edit notebook (owner or editor)
++  can-edit
  |=  [notebook-id=@ud who=ship]
  ^-  ?
  =/  r=(unit role:notes)  (role-for notebook-id who)
  ?~  r  |
  ?|  =(u.r %owner)
      =(u.r %editor)
  ==
::
::  is-owner: check if ship is notebook owner
++  is-owner
  |=  [notebook-id=@ud who=ship]
  ^-  ?
  =/  r=(unit role:notes)  (role-for notebook-id who)
  ?~  r  |
  =(u.r %owner)
::
::  need-notebook: get notebook or crash
++  need-notebook
  |=  notebook-id=@ud
  ^-  notebook:notes
  ~|  [%notes %notebook-not-found notebook-id]
  (~(got by notebooks.state) notebook-id)
::
::  need-folder: get folder or crash
++  need-folder
  |=  folder-id=@ud
  ^-  folder:notes
  ~|  [%notes %folder-not-found folder-id]
  (~(got by folders.state) folder-id)
::
::  need-note: get note or crash
++  need-note
  |=  note-id=@ud
  ^-  note:notes
  ~|  [%notes %note-not-found note-id]
  (~(got by notes.state) note-id)
::
::  touch-notebook: update notebook timestamp
++  touch-notebook
  |=  [st=raw-state notebook-id=@ud]
  ^-  raw-state
  =/  nb=(unit notebook:notes)  (~(get by notebooks.st) notebook-id)
  ?~  nb  st
  st(notebooks (~(put by notebooks.st) notebook-id u.nb(updated-at now.bowl)))
::
::  event-notebook-id: extract notebook id from domain event
++  event-notebook-id
  |=  evt=event:notes
  ^-  @ud
  ?-  -.evt
      %notebook-created    notebook-id.evt
      %notebook-renamed    notebook-id.evt
      %member-joined       notebook-id.evt
      %member-left         notebook-id.evt
      %folder-created      notebook-id.evt
      %folder-renamed      notebook-id.evt
      %folder-moved        notebook-id.evt
      %folder-deleted      notebook-id.evt
      %note-created        notebook-id.evt
      %note-renamed        notebook-id.evt
      %note-moved          notebook-id.evt
      %note-deleted        notebook-id.evt
      %note-updated        notebook-id.evt
  ==
::
::  event-cards: cards for update broadcast at seq
++  event-cards
  |=  [seq=@ud evt=u-notes:notes]
  ^-  (list card)
  =/  notebook-id=@ud  (event-notebook-id evt)
  =/  notebook-path=@t  (scot %ud notebook-id)
  =/  res=r-notes:notes  [%update seq evt]
  :~  [%give %fact [/v0/events/[notebook-path]]~ %notes-update !>(evt)]
      [%give %fact [/v0/stream/[notebook-path]]~ %notes-response !>(res)]
  ==
::
++  commit-update
  |=  [st=raw-state evt=u-notes:notes]
  ^+  cor
  =/  seq=@ud  +(next-update-id.st)
  =/  st2=raw-state
    %_  st
      updates          (~(put by updates.st) seq evt)
      next-update-id   seq
    ==
  =/  cards2=(list card:agent:gall)
    (welp (flop (event-cards [seq evt])) cards)
  =.  state  st2
  cor(cards cards2)
::
::  all-folders-in-notebook: list all folders for a notebook
++  all-folders-in-notebook
  |=  notebook-id=@ud
  ^-  (list folder:notes)
  %+  murn  ~(tap by folders.state)
  |=  [fid=@ud fld=folder:notes]
  ?:  =(notebook-id.fld notebook-id)
    `fld
  ~
::
::  all-notes-in-notebook: list all notes for a notebook
++  all-notes-in-notebook
  |=  notebook-id=@ud
  ^-  (list note:notes)
  %+  murn  ~(tap by notes.state)
  |=  [nid=@ud nt=note:notes]
  ?:  =(notebook-id.nt notebook-id)
    `nt
  ~
::
::  all-notes-in-folder: list all notes in a folder
++  all-notes-in-folder
  |=  folder-id=@ud
  ^-  (list note:notes)
  %+  murn  ~(tap by notes.state)
  |=  [nid=@ud nt=note:notes]
  ?:  =(folder-id.nt folder-id)
    `nt
  ~
::
::  folder-children-ids: get direct child folder ids
++  folder-children-ids
  |=  folder-id=@ud
  ^-  (list @ud)
  %+  murn  ~(tap by folders.state)
  |=  [fid=@ud fld=folder:notes]
  ?~  parent-folder-id.fld  ~
  ?:  =(u.parent-folder-id.fld folder-id)
    `fid
  ~
::
::  subtree-folder-ids: get folder and all descendants
++  subtree-folder-ids
  |=  folder-id=@ud
  ^-  (set @ud)
  =/  acc=(set @ud)  (silt ~[folder-id])
  =/  queue=(list @ud)  ~[folder-id]
  |-
  ?~  queue  acc
  =/  children=(list @ud)  (folder-children-ids i.queue)
  %=  $
    queue  (weld t.queue children)
    acc    (~(gas in acc) children)
  ==
::
::  note-ids-in-folder-set: get all note ids in a set of folders
++  note-ids-in-folder-set
  |=  fids=(set @ud)
  ^-  (set @ud)
  %-  silt
  %+  murn  ~(tap by notes.state)
  |=  [nid=@ud nt=note:notes]
  ?:  (~(has in fids) folder-id.nt)
    `nid
  ~
::
::  del-many-folders: delete multiple folders from map
++  del-many-folders
  |=  [fmap=(map @ud folder:notes) fids=(set @ud)]
  ^-  (map @ud folder:notes)
  %-  ~(rep in fids)
  |=  [fid=@ud acc=_fmap]
  (~(del by acc) fid)
::
::  del-many-notes: delete multiple notes from map
++  del-many-notes
  |=  [nmap=(map @ud note:notes) nids=(set @ud)]
  ^-  (map @ud note:notes)
  %-  ~(rep in nids)
  |=  [nid=@ud acc=_nmap]
  (~(del by acc) nid)
::
++  updates-since
  |=  [notebook-id=@ud since=@ud]
  ^-  (list [seq=@ud evt=u-notes:notes])
  %+  murn  ~(tap by updates.state)
  |=  [seq=@ud evt=u-notes:notes]
  ?:  &((gth seq since) =(notebook-id (event-notebook-id evt)))
    `[seq evt]
  ~
--
