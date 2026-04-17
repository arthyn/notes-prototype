::  notes: shared notebook Gall agent (dual-mode host/subscriber)
::
/-  notes
/+  default-agent, dbug, verb, notes-json
/=  index  /lib/notes-ui
::
|%
+$  card  card:agent:gall
+$  current-state  state-2:notes
--
::
=|  current-state
=*  state  -
::
%-  agent:dbug
%+  verb  |
^-  agent:gall
=<
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
    cor   ~(. +> [bowl ~])
::
++  on-init
  ^-  (quip card _this)
  =^  cards  state
    abet:init:cor
  [cards this]
::
++  on-save
  ^-  vase
  !>(state)
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =^  cards  state
    abet:(load:cor old)
  [cards this]
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  =^  cards  state
    abet:(poke:cor mark vase)
  [cards this]
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  =^  cards  state
    abet:(watch:cor `(pole knot)`path)
  [cards this]
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  (peek:cor `(pole knot)`path)
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  =^  cards  state
    abet:(agent:cor `(pole knot)`wire sign)
  [cards this]
::
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  =^  cards  state
    abet:(arvo:cor wire sign-arvo)
  [cards this]
::
++  on-leave  on-leave:def
++  on-fail   on-fail:def
--
::  helper core
::
|_  [=bowl:gall cards=(list card)]
++  dummy  'dot-right-v1'
++  abet  [(flop cards) state]
++  cor   .
++  emit  |=(=card cor(cards [card cards]))
++  emil  |=(caz=(list card) cor(cards (welp (flop caz) cards)))
++  give  |=(=gift:agent:gall (emit %give gift))
::
++  init
  ^+  cor
  %-  emit
  [%pass /eyre/notes %arvo %e %connect [~ /notes] %notes]
::
++  load
  |=  old=vase
  ^+  cor
  ::  peek at head tag without type-checking
  =/  raw=*  q.old
  =/  tag=@
    ?:  ?=(^ raw)
      ;;(@ -.raw)
    0
  ::  state-2: current format
  ?:  =(tag %2)
    =/  s=current-state  !<(current-state old)
    =.  state  s
    cor
  ::  state-1: migrate by adding empty published map
  ?:  =(tag %1)
    =/  s=state-1:notes  !<(state-1:notes old)
    =.  state  [%2 books.s next-id.s ~]
    cor
  ::  state-0 or unknown: start fresh
  ::  acceptable during this migration; task says single-player breakage is ok
  cor
::
++  poke
  |=  [=mark =vase]
  ^+  cor
  ?+  mark  ~|(bad-mark+mark !!)
      %handle-http-request
    =/  req  !<([eyre-id=@ta =inbound-request:eyre] vase)
    =/  url=@t  url.request.inbound-request.req
    =/  url-tape=tape  (trip url)
    ::  check if this is a published note request: /notes/pub/{note-id}
    =/  pub-html=(unit @t)
      ?.  =("/notes/pub/" (scag 11 url-tape))  ~
      =/  id-tape=tape  (slag 11 url-tape)
      =/  nid=@ud  (fall (rush (crip id-tape) dem) 0)
      ?:  =(0 nid)  ~
      (~(get by published.state) nid)
    ::  serve published note or the UI
    =/  data=octs
      ?^  pub-html
        [(met 3 u.pub-html) u.pub-html]
      [(met 3 index) index]
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
      %notes-action
    =/  ra=routed-action:notes  !<(routed-action:notes vase)
    =/  act=action:notes  action.ra
    ::  for %create-notebook we always act as local host
    ?:  ?=(%create-notebook -.act)
      se-abet:(se-create-notebook:(se-init:se-core act) act)
    ::  remote join/leave actions: flag is carried directly in the action
    ?:  ?=(%join-remote -.act)
      (join-remote flag.act)
    ?:  ?=(%leave-remote -.act)
      (leave-remote flag.act)
    ::  publish/unpublish are local-only, not forwarded to remote hosts
    ?:  ?=(%publish-note -.act)
      =.  published.state  (~(put by published.state) note-id.act html.act)
      cor
    ?:  ?=(%unpublish-note -.act)
      =.  published.state  (~(del by published.state) note-id.act)
      cor
    ::  use explicit flag from _flag field if present,
    ::  otherwise fall back to notebook-id lookup
    =/  =flag:notes
      ?^  target.ra
        u.target.ra
      (find-flag-by-nid (action-notebook-id act))
    =/  entry=[=net:notes =notebook-state:notes]
      (~(got by books.state) flag)
    ?:  ?=(%pub -.net.entry)
      ::  we host it — process as server command
      =/  cmd=command:notes
        (action-to-command act src.bowl)
      se-abet:(se-poke:(se-abed:se-core flag) cmd)
    ::  we subscribe to it — forward to host
    no-abet:(no-action:(no-abed:no-core flag) act)
  ::
      %notes-command
    =/  cmd=command:notes  !<(command:notes vase)
    ::  %join-remote and %leave-remote carry their own flag
    ?:  ?=(%join-remote -.cmd)
      ?>  =(ship.flag.cmd our.bowl)
      ?>  (~(has by books.state) flag.cmd)
      se-abet:(se-poke:(se-abed:se-core flag.cmd) cmd)
    ?:  ?=(%leave-remote -.cmd)
      ?>  =(ship.flag.cmd our.bowl)
      ?>  (~(has by books.state) flag.cmd)
      se-abet:(se-poke:(se-abed:se-core flag.cmd) cmd)
    ::  commands always processed by server core
    =/  nid=@ud  (command-notebook-id cmd)
    =/  =flag:notes  [our.bowl (scot %ud nid)]
    ?>  (~(has by books.state) flag)
    se-abet:(se-poke:(se-abed:se-core flag) cmd)
  ==
::
::  +join-remote: initiate joining a notebook on a remote ship
++  join-remote
  |=  =flag:notes
  ^+  cor
  ::  must be a remote ship, not ourselves
  ?<  =(our.bowl ship.flag)
  ::  must not already be tracking this notebook
  ?<  (~(has by books.state) flag)
  ::  create placeholder entry with %sub net, not yet initialized
  =/  placeholder-net=net:notes  [%sub *@da |]
  =/  placeholder-nb=notebook:notes
    [0 '' ship.flag *@da *@da]
  =/  placeholder-nb-state=notebook-state:notes
    [placeholder-nb ~ ~ ~]
  =.  books.state
    (~(put by books.state) flag [placeholder-net placeholder-nb-state])
  ::  poke the host ship to add us as a member
  =/  join-cmd=command:notes
    [%join-remote flag src.bowl]
  =/  join-wire=path
    /notes/join/(scot %p ship.flag)/[name.flag]
  %-  emit
  [%pass join-wire %agent [ship.flag %notes] %poke notes-command+!>(join-cmd)]
::
::  +leave-remote: leave a notebook on a remote ship
++  leave-remote
  |=  =flag:notes
  ^+  cor
  ::  must exist in books
  ?>  (~(has by books.state) flag)
  no-abet:no-leave:(no-abed:no-core flag)
::
++  watch
  |=  =(pole knot)
  ^+  cor
  ?+  pole  ~|(bad-watch-path+pole !!)
      [%http-response *]
    cor
  ::
      [%v0 %notes ship=@ name=@ %updates ~]
    ::  subscriber watching our notebook's update stream
    =/  =ship  (slav %p ship.pole)
    =/  name=@t  name.pole
    =/  =flag:notes  [ship name]
    ?>  =(our.bowl ship)
    =/  entry=(unit [=net:notes =notebook-state:notes])
      (~(get by books.state) flag)
    ?~  entry  ~|(notebook-not-found+flag !!)
    ?>  ?=(%pub -.net.u.entry)
    ?>  (se-can-view:(se-abed:se-core flag) src.bowl)
    ::  send initial snapshot
    se-abet:(se-watch-sub:(se-abed:se-core flag) src.bowl)
  ::
      [%v0 %notes ship=@ name=@ %stream ~]
    ::  local UI subscription
    =/  =ship  (slav %p ship.pole)
    =/  name=@t  name.pole
    =/  =flag:notes  [ship name]
    =/  entry=(unit [=net:notes =notebook-state:notes])
      (~(get by books.state) flag)
    ?~  entry  ~|(notebook-not-found+flag !!)
    ?>  (can-view-flag flag src.bowl)
    ::  send initial snapshot
    =/  snap=response:notes  [%snapshot flag notebook-state.u.entry]
    %-  give
    [%fact [`path`pole]~ notes-response+!>(snap)]
  ==
::
++  peek
  |=  =(pole knot)
  ^-  (unit (unit cage))
  ?+  pole  ~
    ::  /x/ui — serve the frontend
      [%x %ui ~]
    ``html+!>(index)
    ::  /x/v0/notebooks — list all notebooks
      [%x %v0 %notebooks ~]
    =/  nbs=(list json)
      %+  murn  ~(tap by books.state)
      |=  [=flag:notes [=net:notes =notebook-state:notes]]
      ?.  (can-view-flag flag src.bowl)  ~
      =-  `(pairs:enjs:format -)
      :~  ['host' s+(scot %p ship.flag)]
          ['flagName' s+name.flag]
          ['notebook' (notebook:enjs:notes-json notebook.notebook-state)]
      ==
    ``json+!>([%a nbs])
    ::  /x/v0/notebook/<ship>/<name>
      [%x %v0 %notebook ship=@ name=@ ~]
    =/  =flag:notes  [(slav %p ship.pole) name.pole]
    =/  entry=(unit [=net:notes =notebook-state:notes])
      (~(get by books.state) flag)
    ?~  entry  ``json+!>(~)
    ?>  (can-view-flag flag src.bowl)
    =-  ``json+!>((pairs:enjs:format -))
    :~  ['host' s+(scot %p ship.flag)]
        ['flagName' s+name.flag]
        ['notebook' (notebook:enjs:notes-json notebook.notebook-state.u.entry)]
    ==
    ::  /x/v0/folders/<ship>/<name>
      [%x %v0 %folders ship=@ name=@ ~]
    =/  =flag:notes  [(slav %p ship.pole) name.pole]
    =/  entry=(unit [=net:notes =notebook-state:notes])
      (~(get by books.state) flag)
    ?~  entry  ``json+!>(~)
    ?>  (can-view-flag flag src.bowl)
    =/  flds=(list json)
      %+  turn  ~(val by folders.notebook-state.u.entry)
      folder:enjs:notes-json
    ``json+!>([%a flds])
    ::  /x/v0/notes/<ship>/<name>
      [%x %v0 %notes ship=@ name=@ ~]
    =/  =flag:notes  [(slav %p ship.pole) name.pole]
    =/  entry=(unit [=net:notes =notebook-state:notes])
      (~(get by books.state) flag)
    ?~  entry  ``json+!>(~)
    ?>  (can-view-flag flag src.bowl)
    =/  nts=(list json)
      %+  turn  ~(val by notes.notebook-state.u.entry)
      note:enjs:notes-json
    ``json+!>([%a nts])
    ::  /x/v0/note/<ship>/<name>/<id> — single note by ID
      [%x %v0 %note ship=@ name=@ id=@ ~]
    =/  =flag:notes  [(slav %p ship.pole) name.pole]
    =/  entry=(unit [=net:notes =notebook-state:notes])
      (~(get by books.state) flag)
    ?~  entry  ``json+!>(~)
    ?>  (can-view-flag flag src.bowl)
    =/  nid=@ud  (slav %ud id.pole)
    =/  nt=(unit note:notes)
      (~(get by notes.notebook-state.u.entry) nid)
    ?~  nt  ``json+!>(~)
    ``json+!>((note:enjs:notes-json u.nt))
    ::  /x/v0/folder/<ship>/<name>/<id> — single folder by ID
      [%x %v0 %folder ship=@ name=@ id=@ ~]
    =/  =flag:notes  [(slav %p ship.pole) name.pole]
    =/  entry=(unit [=net:notes =notebook-state:notes])
      (~(get by books.state) flag)
    ?~  entry  ``json+!>(~)
    ?>  (can-view-flag flag src.bowl)
    =/  fid=@ud  (slav %ud id.pole)
    =/  fld=(unit folder:notes)
      (~(get by folders.notebook-state.u.entry) fid)
    ?~  fld  ``json+!>(~)
    ``json+!>((folder:enjs:notes-json u.fld))
    ::  /x/v0/members/<ship>/<name>
      [%x %v0 %members ship=@ name=@ ~]
    =/  =flag:notes  [(slav %p ship.pole) name.pole]
    =/  entry=(unit [=net:notes =notebook-state:notes])
      (~(get by books.state) flag)
    ?~  entry  ``json+!>(~)
    ?>  (can-view-flag flag src.bowl)
    =/  mlist=(list json)
      %+  turn  ~(tap by notebook-members.notebook-state.u.entry)
      |=  [who=ship r=role:notes]
      %-  pairs:enjs:format
      :~  ['ship' s+(scot %p who)]
          ['role' s+(scot %tas r)]
      ==
    ``json+!>([%a mlist])
    ::  /x/v0/published — list of published note IDs
      [%x %v0 %published ~]
    =/  ids=(list json)
      %+  turn  ~(tap in ~(key by published.state))
      numb:enjs:format
    ``json+!>([%a ids])
  ==
::
++  agent
  |=  [=(pole knot) =sign:agent:gall]
  ^+  cor
  ?+  pole  ~|(bad-agent-wire+pole !!)
      [%notes %sub ship=@ name=@ ~]
    =/  =flag:notes
      [(slav %p ship.pole) name.pole]
    ?.  (~(has by books.state) flag)
      cor
    no-abet:(no-agent:(no-abed:no-core flag) sign)
  ::
      [%notes %join ship=@ name=@ ~]
    =/  =flag:notes
      [(slav %p ship.pole) name.pole]
    ?+  -.sign  cor
        %poke-ack
      ?~  p.sign
        ::  poke succeeded — host has added us as member, now subscribe
        no-abet:no-start-watch:(no-abed:no-core flag)
      ::  poke failed — remove placeholder from books
      =.  books.state  (~(del by books.state) flag)
      cor
    ==
  ==
::
::  +find-flag-by-nid: find the flag for a notebook by its numeric id
++  find-flag-by-nid
  |=  nid=@ud
  ^-  flag:notes
  =/  matches=(list flag:notes)
    %+  murn  ~(tap by books.state)
    |=  [=flag:notes [=net:notes =notebook-state:notes]]
    ?:  =(nid id.notebook.notebook-state)
      `flag
    ~
  ?~  matches  ~|(notebook-not-found+nid !!)
  i.matches
::
++  arvo
  |=  [=wire =sign-arvo]
  ^+  cor
  ?+  sign-arvo  ~|(bad-arvo-sign+wire !!)
    [%eyre %bound *]  cor
  ==
::
::  +can-view-flag: check if ship can view a notebook by flag
++  can-view-flag
  |=  [=flag:notes who=ship]
  ^-  ?
  =/  entry=(unit [=net:notes =notebook-state:notes])
    (~(get by books.state) flag)
  ?~  entry  |
  =/  mbrs=notebook-members:notes
    notebook-members.notebook-state.u.entry
  ?~  (~(get by mbrs) who)  |
  &
::
::  +action-notebook-id: extract notebook id from action
++  action-notebook-id
  |=  act=action:notes
  ^-  @ud
  ?-  -.act
      %create-notebook      0
      %rename-notebook      notebook-id.act
      %join                 notebook-id.act
      %leave                notebook-id.act
      %join-remote          0
      %leave-remote         0
      %create-folder        notebook-id.act
      %rename-folder        notebook-id.act
      %move-folder          notebook-id.act
      %delete-folder        notebook-id.act
      %create-note          notebook-id.act
      %rename-note          notebook-id.act
      %move-note            notebook-id.act
      %delete-note          notebook-id.act
      %update-note          notebook-id.act
      %batch-import         notebook-id.act
      %batch-import-tree    notebook-id.act
      %publish-note         notebook-id.act
      %unpublish-note       notebook-id.act
  ==
::
::  +command-notebook-id: extract notebook id from command
++  command-notebook-id
  |=  cmd=command:notes
  ^-  @ud
  ?-  -.cmd
      %create-notebook      0
      %rename-notebook      notebook-id.cmd
      %join                 notebook-id.cmd
      %leave                notebook-id.cmd
      %join-remote          0
      %leave-remote         0
      %create-folder        notebook-id.cmd
      %rename-folder        notebook-id.cmd
      %move-folder          notebook-id.cmd
      %delete-folder        notebook-id.cmd
      %create-note          notebook-id.cmd
      %rename-note          notebook-id.cmd
      %move-note            notebook-id.cmd
      %delete-note          notebook-id.cmd
      %update-note          notebook-id.cmd
      %batch-import         notebook-id.cmd
      %batch-import-tree    notebook-id.cmd
  ==
::
::  +action-to-command: convert action to command, adding actor
++  action-to-command
  |=  [act=action:notes actor=ship]
  ^-  command:notes
  ?-  -.act
      %create-notebook      [%create-notebook title.act actor]
      %rename-notebook      [%rename-notebook notebook-id.act title.act actor]
      %join                 [%join notebook-id.act actor]
      %leave                [%leave notebook-id.act actor]
      %join-remote          [%join-remote flag.act actor]
      %leave-remote         [%leave-remote flag.act actor]
      %create-folder        [%create-folder notebook-id.act parent-folder-id.act name.act actor]
      %rename-folder        [%rename-folder notebook-id.act folder-id.act name.act actor]
      %move-folder          [%move-folder notebook-id.act folder-id.act new-parent-folder-id.act actor]
      %delete-folder        [%delete-folder notebook-id.act folder-id.act recursive.act actor]
      %create-note          [%create-note notebook-id.act folder-id.act title.act body-md.act actor]
      %rename-note          [%rename-note notebook-id.act note-id.act title.act actor]
      %move-note            [%move-note note-id.act notebook-id.act folder-id.act actor]
      %delete-note          [%delete-note note-id.act notebook-id.act actor]
      %update-note          [%update-note notebook-id.act note-id.act body-md.act expected-revision.act actor]
      %batch-import         [%batch-import notebook-id.act folder-id.act notes.act actor]
      %batch-import-tree    [%batch-import-tree notebook-id.act parent-folder-id.act tree.act actor]
      %publish-note         !!
      %unpublish-note       !!
  ==
::
::  ====  se-core: server/host core  ====
::
++  se-core
  |_  [=flag:notes =log:notes =notebook-state:notes gone=_|]
  ++  se-core  .
  ++  emit  |=(=card se-core(cor cor(cards [card cards])))
  ++  give  |=(=gift:agent:gall (emit %give gift))
  ::
  ::  +se-init: initialize for a brand-new notebook (before it's in state)
  ++  se-init
    |=  act=action:notes
    ^+  se-core
    =/  nid=@ud  +(next-id.state)
    =/  =flag:notes  [our.bowl (scot %ud nid)]
    se-core(flag flag)
  ::
  ::  +se-abed: load from state for a given flag
  ++  se-abed
    |=  f=flag:notes
    ^+  se-core
    ?>  =(ship.f our.bowl)
    =/  entry=(unit [=net:notes =notebook-state:notes])
      (~(get by books.state) f)
    ?~  entry  ~|(se-abed-not-found+f !!)
    =/  [=net:notes =notebook-state:notes]  u.entry
    ?>  ?=(%pub -.net)
    se-core(flag f, log log.net, notebook-state notebook-state)
  ::
  ::  +se-abet: write back to cor, updating state
  ++  se-abet
    ^+  cor
    =.  books.state
      ?:  gone
        (~(del by books.state) flag)
      (~(put by books.state) flag [[%pub log] notebook-state])
    cor
  ::
  ::  +se-area: base path for this notebook's subscriptions
  ++  se-area
    `path`/v0/notes/(scot %p ship.flag)/[name.flag]
  ::
  ::  +se-sub-path: update stream subscription path
  ++  se-sub-path
    `path`(weld se-area /updates)
  ::
  ::  +se-update: append update to log and broadcast to subscribers
  ++  se-update
    |=  =u-notes:notes
    ^+  se-core
    ::  find a unique timestamp (bump if collision), following groups pattern
    =/  ts=@da
      |-
      =/  existing  (get:log-on:notes log now.bowl)
      ?~  existing  now.bowl
      $(now.bowl `@da`(add now.bowl ^~((div ~s1 (bex 16)))))
    =.  log  (put:log-on:notes log [ts u-notes])
    ::  broadcast fact to subscribers on both the update and stream paths
    =/  =response:notes  [%update ts u-notes]
    =/  stream-path=path  (weld se-area /stream)
    =/  paths=(list path)  ~[se-sub-path stream-path]
    %-  give
    [%fact paths notes-response+!>(response)]
  ::
  ::  +se-watch-sub: send initial snapshot to a new subscriber
  ++  se-watch-sub
    |=  who=ship
    ^+  se-core
    =/  snap=response:notes  [%snapshot flag notebook-state]
    %-  give
    [%fact ~ notes-response+!>(snap)]
  ::
  ::  +se-can-view: check if ship is a member
  ++  se-can-view
    |=  who=ship
    ^-  ?
    ?~  (~(get by notebook-members.notebook-state) who)  |
    &
  ::
  ::  +se-can-edit: check if ship is owner or editor
  ++  se-can-edit
    |=  who=ship
    ^-  ?
    =/  r=(unit role:notes)
      (~(get by notebook-members.notebook-state) who)
    ?~  r  |
    ?|  =(u.r %owner)
        =(u.r %editor)
    ==
  ::
  ::  +se-is-owner: check if ship is the owner
  ++  se-is-owner
    |=  who=ship
    ^-  ?
    =/  r=(unit role:notes)
      (~(get by notebook-members.notebook-state) who)
    ?~  r  |
    =(u.r %owner)
  ::
  ::  +se-create-notebook: handle %create-notebook action
  ::  called via se-init so flag is pre-set to a new flag
  ++  se-create-notebook
    |=  act=action:notes
    ?>  ?=(%create-notebook -.act)
    ^+  se-core
    ::  nid comes from flag (set by se-init as +(next-id.state))
    =/  nid=@ud  (slav %ud name.flag)
    ::  rfid is nid+1 (root folder gets the next slot)
    =/  rfid=@ud  +(nid)
    =/  nb=notebook:notes
      [nid title.act our.bowl now.bowl now.bowl]
    =/  rf=folder:notes
      [rfid nid '/' ~ our.bowl now.bowl now.bowl]
    =/  mbrs=notebook-members:notes
      (~(put by *notebook-members:notes) our.bowl %owner)
    =/  nb-state=notebook-state:notes
      [nb mbrs ~ ~]
    =.  nb-state
      nb-state(folders (~(put by folders.nb-state) rfid rf))
    =.  next-id.state  rfid
    =.  notebook-state  nb-state
    =.  books.state
      (~(put by books.state) flag [[%pub *log:notes] notebook-state])
    (se-update [%notebook-created nb our.bowl])
  ::
  ::  +se-poke: dispatch a command to the right handler
  ++  se-poke
    |=  cmd=command:notes
    ^+  se-core
    ?-  -.cmd
        %create-notebook
      ~|(%se-poke-create-via-command !!)
        %rename-notebook      (se-rename-notebook cmd)
        %join                 (se-join cmd)
        %leave                (se-leave cmd)
        %join-remote          (se-join-remote cmd)
        %leave-remote         (se-leave-remote cmd)
        %create-folder        (se-create-folder cmd)
        %rename-folder        (se-rename-folder cmd)
        %move-folder          (se-move-folder cmd)
        %delete-folder        (se-delete-folder cmd)
        %create-note          (se-create-note cmd)
        %rename-note          (se-rename-note cmd)
        %move-note            (se-move-note cmd)
        %delete-note          (se-delete-note cmd)
        %update-note          (se-update-note cmd)
        %batch-import         (se-batch-import cmd)
        %batch-import-tree    (se-batch-import-tree cmd)
    ==
  ::
  ++  se-rename-notebook
    |=  cmd=command:notes
    ?>  ?=(%rename-notebook -.cmd)
    ^+  se-core
    ?>  (se-is-owner actor.cmd)
    =/  nb=notebook:notes  notebook.notebook-state
    =.  nb  nb(title title.cmd, updated-at now.bowl)
    =.  notebook.notebook-state  nb
    (se-update [%notebook-renamed notebook-id.cmd title.cmd actor.cmd])
  ::
  ++  se-join
    |=  cmd=command:notes
    ?>  ?=(%join -.cmd)
    ^+  se-core
    =/  new-mbrs=notebook-members:notes
      (~(put by notebook-members.notebook-state) actor.cmd %editor)
    =.  notebook-members.notebook-state  new-mbrs
    (se-update [%member-joined notebook-id.cmd actor.cmd %editor actor.cmd])
  ::
  ++  se-leave
    |=  cmd=command:notes
    ?>  ?=(%leave -.cmd)
    ^+  se-core
    =/  new-mbrs=notebook-members:notes
      (~(del by notebook-members.notebook-state) actor.cmd)
    =.  notebook-members.notebook-state  new-mbrs
    (se-update [%member-left notebook-id.cmd actor.cmd actor.cmd])
  ::
  ::  +se-join-remote: add a remote ship as an editor (called from poke on host)
  ++  se-join-remote
    |=  cmd=command:notes
    ?>  ?=(%join-remote -.cmd)
    ^+  se-core
    =/  nid=@ud  id.notebook.notebook-state
    =/  new-mbrs=notebook-members:notes
      (~(put by notebook-members.notebook-state) actor.cmd %editor)
    =.  notebook-members.notebook-state  new-mbrs
    (se-update [%member-joined nid actor.cmd %editor actor.cmd])
  ::
  ::  +se-leave-remote: remove a remote ship from membership (called from poke on host)
  ++  se-leave-remote
    |=  cmd=command:notes
    ?>  ?=(%leave-remote -.cmd)
    ^+  se-core
    =/  nid=@ud  id.notebook.notebook-state
    =/  new-mbrs=notebook-members:notes
      (~(del by notebook-members.notebook-state) actor.cmd)
    =.  notebook-members.notebook-state  new-mbrs
    (se-update [%member-left nid actor.cmd actor.cmd])
  ::
  ++  se-create-folder
    |=  cmd=command:notes
    ?>  ?=(%create-folder -.cmd)
    ^+  se-core
    ?>  (se-can-edit actor.cmd)
    ?^  parent-folder-id.cmd
      =/  pf=folder:notes
        (~(got by folders.notebook-state) u.parent-folder-id.cmd)
      ?>  =(notebook-id.pf notebook-id.cmd)
      =/  fid=@ud  +(next-id.state)
      =.  next-id.state  fid
      =/  nf=folder:notes
        [fid notebook-id.cmd name.cmd parent-folder-id.cmd actor.cmd now.bowl now.bowl]
      =.  folders.notebook-state
        (~(put by folders.notebook-state) fid nf)
      (se-update [%folder-created nf actor.cmd])
    =/  fid=@ud  +(next-id.state)
    =.  next-id.state  fid
    =/  nf=folder:notes
      [fid notebook-id.cmd name.cmd ~ actor.cmd now.bowl now.bowl]
    =.  folders.notebook-state
      (~(put by folders.notebook-state) fid nf)
    (se-update [%folder-created nf actor.cmd])
  ::
  ++  se-rename-folder
    |=  cmd=command:notes
    ?>  ?=(%rename-folder -.cmd)
    ^+  se-core
    ?>  (se-can-edit actor.cmd)
    =/  fld=folder:notes
      (~(got by folders.notebook-state) folder-id.cmd)
    ?>  =(notebook-id.fld notebook-id.cmd)
    =.  fld  fld(name name.cmd, updated-at now.bowl)
    =.  folders.notebook-state
      (~(put by folders.notebook-state) folder-id.cmd fld)
    (se-update [%folder-renamed folder-id.cmd notebook-id.cmd name.cmd actor.cmd])
  ::
  ++  se-move-folder
    |=  cmd=command:notes
    ?>  ?=(%move-folder -.cmd)
    ^+  se-core
    ?>  (se-can-edit actor.cmd)
    =/  fld=folder:notes
      (~(got by folders.notebook-state) folder-id.cmd)
    ?>  =(notebook-id.fld notebook-id.cmd)
    =/  npf=folder:notes
      (~(got by folders.notebook-state) new-parent-folder-id.cmd)
    ?>  =(notebook-id.npf notebook-id.cmd)
    ::  cannot move into itself or descendants
    =/  subtree=(set @ud)
      (se-subtree-folder-ids folder-id.cmd)
    ?<  (~(has in subtree) new-parent-folder-id.cmd)
    =.  fld  fld(parent-folder-id `new-parent-folder-id.cmd, updated-at now.bowl)
    =.  folders.notebook-state
      (~(put by folders.notebook-state) folder-id.cmd fld)
    (se-update [%folder-moved folder-id.cmd notebook-id.cmd new-parent-folder-id.cmd actor.cmd])
  ::
  ++  se-delete-folder
    |=  cmd=command:notes
    ?>  ?=(%delete-folder -.cmd)
    ^+  se-core
    ?>  (se-can-edit actor.cmd)
    =/  fld=folder:notes
      (~(got by folders.notebook-state) folder-id.cmd)
    ?>  =(notebook-id.fld notebook-id.cmd)
    ::  cannot delete root folder
    ?>  ?=(^ parent-folder-id.fld)
    ?:  recursive.cmd
      =/  del-fids=(set @ud)
        (se-subtree-folder-ids folder-id.cmd)
      =/  del-nids=(set @ud)
        (se-note-ids-in-folder-set del-fids)
      =.  folders.notebook-state
        %-  ~(rep in del-fids)
        |=  [fid=@ud acc=_folders.notebook-state]
        (~(del by acc) fid)
      =.  notes.notebook-state
        %-  ~(rep in del-nids)
        |=  [nid=@ud acc=_notes.notebook-state]
        (~(del by acc) nid)
      (se-update [%folder-deleted folder-id.cmd notebook-id.cmd actor.cmd])
    ::  non-recursive: fail if has children
    =/  children=(list @ud)
      (se-folder-children-ids folder-id.cmd)
    ?>  =(~ children)
    =/  child-notes=(list note:notes)
      (se-notes-in-folder folder-id.cmd)
    ?>  =(~ child-notes)
    =.  folders.notebook-state
      (~(del by folders.notebook-state) folder-id.cmd)
    (se-update [%folder-deleted folder-id.cmd notebook-id.cmd actor.cmd])
  ::
  ++  se-create-note
    |=  cmd=command:notes
    ?>  ?=(%create-note -.cmd)
    ^+  se-core
    ?>  (se-can-edit actor.cmd)
    =/  fld=folder:notes
      (~(got by folders.notebook-state) folder-id.cmd)
    ?>  =(notebook-id.fld notebook-id.cmd)
    =/  nid=@ud  +(next-id.state)
    =.  next-id.state  nid
    =/  nt=note:notes
      :*  nid
          notebook-id.cmd
          folder-id.cmd
          title.cmd
          ~
          body-md.cmd
          actor.cmd
          now.bowl
          actor.cmd
          now.bowl
          0
      ==
    =.  notes.notebook-state
      (~(put by notes.notebook-state) nid nt)
    (se-update [%note-created nt actor.cmd])
  ::
  ++  se-rename-note
    |=  cmd=command:notes
    ?>  ?=(%rename-note -.cmd)
    ^+  se-core
    ?>  (se-can-edit actor.cmd)
    =/  nt=note:notes
      (~(got by notes.notebook-state) note-id.cmd)
    ?>  =(notebook-id.nt notebook-id.cmd)
    =.  nt
      %_  nt
        title       title.cmd
        updated-by  actor.cmd
        updated-at  now.bowl
        revision    +(revision.nt)
      ==
    =.  notes.notebook-state
      (~(put by notes.notebook-state) note-id.cmd nt)
    (se-update [%note-renamed note-id.cmd notebook-id.cmd title.cmd actor.cmd])
  ::
  ++  se-move-note
    |=  cmd=command:notes
    ?>  ?=(%move-note -.cmd)
    ^+  se-core
    ?>  (se-can-edit actor.cmd)
    =/  nt=note:notes
      (~(got by notes.notebook-state) note-id.cmd)
    =/  fld=folder:notes
      (~(got by folders.notebook-state) folder-id.cmd)
    ?>  =(notebook-id.fld notebook-id.cmd)
    =.  nt
      %_  nt
        notebook-id  notebook-id.cmd
        folder-id    folder-id.cmd
        updated-by   actor.cmd
        updated-at   now.bowl
        revision     +(revision.nt)
      ==
    =.  notes.notebook-state
      (~(put by notes.notebook-state) note-id.cmd nt)
    (se-update [%note-moved note-id.cmd notebook-id.cmd folder-id.cmd actor.cmd])
  ::
  ++  se-delete-note
    |=  cmd=command:notes
    ?>  ?=(%delete-note -.cmd)
    ^+  se-core
    ?>  (se-can-edit actor.cmd)
    =/  nt=note:notes
      (~(got by notes.notebook-state) note-id.cmd)
    ?>  =(notebook-id.nt notebook-id.cmd)
    =.  notes.notebook-state
      (~(del by notes.notebook-state) note-id.cmd)
    (se-update [%note-deleted note-id.cmd notebook-id.cmd actor.cmd])
  ::
  ++  se-update-note
    |=  cmd=command:notes
    ?>  ?=(%update-note -.cmd)
    ^+  se-core
    =/  nt=note:notes
      (~(got by notes.notebook-state) note-id.cmd)
    ?>  (se-can-edit actor.cmd)
    ::  optimistic concurrency check
    ::  when expected-revision is 0, skip the check (force update) —
    ::  subscribers may have stale revisions
    ?:  &(!=(0 expected-revision.cmd) !=(revision.nt expected-revision.cmd))
      ~|(%revision-mismatch !!)
    =.  nt
      %_  nt
        body-md     body-md.cmd
        updated-by  actor.cmd
        updated-at  now.bowl
        revision    +(revision.nt)
      ==
    =.  notes.notebook-state
      (~(put by notes.notebook-state) note-id.cmd nt)
    (se-update [%note-updated nt actor.cmd])
  ::
  ++  se-batch-import
    |=  cmd=command:notes
    ?>  ?=(%batch-import -.cmd)
    ^+  se-core
    ?>  (se-can-edit actor.cmd)
    =/  items=(list [title=@t body-md=@t])  notes.cmd
    |-  ^+  se-core
    ?~  items  se-core
    =/  nid=@ud  +(next-id.state)
    =.  next-id.state  nid
    =/  nt=note:notes
      :*  nid
          notebook-id.cmd
          folder-id.cmd
          title.i.items
          ~
          body-md.i.items
          actor.cmd
          now.bowl
          actor.cmd
          now.bowl
          0
      ==
    =.  notes.notebook-state
      (~(put by notes.notebook-state) nid nt)
    =.  se-core  (se-update [%note-created nt actor.cmd])
    $(items t.items, se-core se-core)
  ::
  ++  se-batch-import-tree
    |=  cmd=command:notes
    ?>  ?=(%batch-import-tree -.cmd)
    ^+  se-core
    ?>  (se-can-edit actor.cmd)
    =/  items=(list import-node:notes)  tree.cmd
    =|  stack=(list [remaining=(list import-node:notes) folder-id=@ud])
    =/  fid=@ud  parent-folder-id.cmd
    |-  ^+  se-core
    ?~  items
      ?~  stack
        se-core
      $(items remaining.i.stack, fid folder-id.i.stack, stack t.stack)
    ?-  -.i.items
        %note
      =/  nid=@ud  +(next-id.state)
      =.  next-id.state  nid
      =/  nt=note:notes
        :*  nid
            notebook-id.cmd
            fid
            title.i.items
            ~
            body-md.i.items
            actor.cmd
            now.bowl
            actor.cmd
            now.bowl
            0
        ==
      =.  notes.notebook-state
        (~(put by notes.notebook-state) nid nt)
      =.  se-core  (se-update [%note-created nt actor.cmd])
      $(items t.items, se-core se-core)
    ::
        %folder
      =/  new-fid=@ud  +(next-id.state)
      =.  next-id.state  new-fid
      =/  nf=folder:notes
        [new-fid notebook-id.cmd name.i.items `fid actor.cmd now.bowl now.bowl]
      =.  folders.notebook-state
        (~(put by folders.notebook-state) new-fid nf)
      =.  se-core  (se-update [%folder-created nf actor.cmd])
      $(items children.i.items, stack [[t.items fid] stack], fid new-fid, se-core se-core)
    ==
  ::
  ::  helper: folder children ids
  ++  se-folder-children-ids
    |=  folder-id=@ud
    ^-  (list @ud)
    %+  murn  ~(tap by folders.notebook-state)
    |=  [fid=@ud fld=folder:notes]
    ?~  parent-folder-id.fld  ~
    ?:  =(u.parent-folder-id.fld folder-id)
      `fid
    ~
  ::
  ::  helper: subtree folder ids (folder + all descendants)
  ++  se-subtree-folder-ids
    |=  folder-id=@ud
    ^-  (set @ud)
    =/  acc=(set @ud)  (silt ~[folder-id])
    =/  queue=(list @ud)  ~[folder-id]
    |-
    ?~  queue  acc
    =/  children=(list @ud)  (se-folder-children-ids i.queue)
    %=  $
      queue  (weld t.queue children)
      acc    (~(gas in acc) children)
    ==
  ::
  ::  helper: note ids in a set of folders
  ++  se-note-ids-in-folder-set
    |=  fids=(set @ud)
    ^-  (set @ud)
    %-  silt
    %+  murn  ~(tap by notes.notebook-state)
    |=  [nid=@ud nt=note:notes]
    ?:  (~(has in fids) folder-id.nt)
      `nid
    ~
  ::
  ::  helper: all notes in a folder
  ++  se-notes-in-folder
    |=  folder-id=@ud
    ^-  (list note:notes)
    %+  murn  ~(tap by notes.notebook-state)
    |=  [nid=@ud nt=note:notes]
    ?:  =(folder-id.nt folder-id)
      `nt
    ~
  --
::
::  ====  no-core: subscriber/client core  ====
::
++  no-core
  |_  [=flag:notes =net:notes =notebook-state:notes gone=_|]
  ++  no-core  .
  ++  emit  |=(=card no-core(cor cor(cards [card cards])))
  ++  give  |=(=gift:agent:gall (emit %give gift))
  ::
  ::  +no-abed: load from state for a given flag
  ++  no-abed
    |=  f=flag:notes
    ^+  no-core
    =/  entry=(unit [=net:notes =notebook-state:notes])
      (~(get by books.state) f)
    ?~  entry  ~|(no-abed-not-found+f !!)
    =/  [=net:notes =notebook-state:notes]  u.entry
    ?>  ?=(%sub -.net)
    no-core(flag f, net net, notebook-state notebook-state)
  ::
  ::  +no-abet: write back to cor
  ++  no-abet
    ^+  cor
    =.  books.state
      ?:  gone
        (~(del by books.state) flag)
      (~(put by books.state) flag [net notebook-state])
    cor
  ::
  ::  +no-area: subscription wire/path base
  ++  no-area
    `path`/notes/sub/(scot %p ship.flag)/[name.flag]
  ::
  ::  +no-sub-wire: wire used for watching the host
  ++  no-sub-wire
    `path`/notes/sub/(scot %p ship.flag)/[name.flag]
  ::
  ::  +no-sub-path: path we watch on the host ship
  ++  no-sub-path
    `path`/v0/notes/(scot %p ship.flag)/[name.flag]/updates
  ::
  ::  +no-action: convert local action to command and send poke to host
  ++  no-action
    |=  act=action:notes
    ^+  no-core
    =/  cmd=command:notes
      (action-to-command:cor act src.bowl)
    %-  emit
    :*  %pass
        no-sub-wire
        %agent
        [ship.flag %notes]
        %poke
        notes-command+!>(cmd)
    ==
  ::
  ::  +no-start-watch: begin subscription to host's update stream
  ++  no-start-watch
    ^+  no-core
    %-  emit
    [%pass no-sub-wire %agent [ship.flag %notes] %watch no-sub-path]
  ::
  ::  +no-leave: unsubscribe from host and mark entry for deletion
  ++  no-leave
    ^+  no-core
    =.  gone  &
    %-  emit
    [%pass no-sub-wire %agent [ship.flag %notes] %leave ~]
  ::
  ::  +no-agent: handle sign from host subscription
  ++  no-agent
    |=  =sign:agent:gall
    ^+  no-core
    ?+  -.sign  no-core
        %fact
      =/  =response:notes  !<(response:notes q.cage.sign)
      (no-response response)
    ::
        %kick
      ::  resubscribe
      %-  emit
      :*  %pass
          no-sub-wire
          %agent
          [ship.flag %notes]
          %watch
          no-sub-path
      ==
    ::
        %watch-ack
      ?~  p.sign  no-core
      ::  subscription failed — mark as not initialized
      ?>  ?=(%sub -.net)
      =.  net  net(init |)
      no-core
    ==
  ::
  ::  +no-response: apply an update from the host to local state
  ++  no-response
    |=  =response:notes
    ^+  no-core
    ?-  -.response
        %snapshot
      =.  notebook-state  notebook-state.response
      ?>  ?=(%sub -.net)
      =.  net  net(init &)
      ::  broadcast snapshot to local UI subscribers
      %-  give
      [%fact [/v0/notes/(scot %p ship.flag)/[name.flag]/stream]~ notes-response+!>(response)]
    ::
        %update
      ::  apply update to local notebook-state
      =.  no-core  (no-apply-update u-notes.response)
      ::  broadcast to local UI subscribers
      %-  give
      [%fact [/v0/notes/(scot %p ship.flag)/[name.flag]/stream]~ notes-response+!>(response)]
    ==
  ::
  ::  +no-apply-update: apply a single update to notebook-state
  ++  no-apply-update
    |=  upd=u-notes:notes
    ^+  no-core
    ?-  -.upd
        %notebook-created
      =.  notebook.notebook-state  notebook.upd
      no-core
    ::
        %notebook-renamed
      =.  notebook.notebook-state
        notebook.notebook-state(title title.upd, updated-at now.bowl)
      no-core
    ::
        %member-joined
      =.  notebook-members.notebook-state
        (~(put by notebook-members.notebook-state) who.upd role.upd)
      no-core
    ::
        %member-left
      =.  notebook-members.notebook-state
        (~(del by notebook-members.notebook-state) who.upd)
      no-core
    ::
        %folder-created
      =.  folders.notebook-state
        (~(put by folders.notebook-state) id.folder.upd folder.upd)
      no-core
    ::
        %folder-renamed
      =/  fld=(unit folder:notes)
        (~(get by folders.notebook-state) folder-id.upd)
      ?~  fld  no-core
      =.  folders.notebook-state
        (~(put by folders.notebook-state) folder-id.upd u.fld(name name.upd))
      no-core
    ::
        %folder-moved
      =/  fld=(unit folder:notes)
        (~(get by folders.notebook-state) folder-id.upd)
      ?~  fld  no-core
      =.  folders.notebook-state
        (~(put by folders.notebook-state) folder-id.upd u.fld(parent-folder-id `new-parent-folder-id.upd))
      no-core
    ::
        %folder-deleted
      =.  folders.notebook-state
        (~(del by folders.notebook-state) folder-id.upd)
      no-core
    ::
        %note-created
      =.  notes.notebook-state
        (~(put by notes.notebook-state) id.note.upd note.upd)
      no-core
    ::
        %note-renamed
      =/  nt=(unit note:notes)
        (~(get by notes.notebook-state) note-id.upd)
      ?~  nt  no-core
      =.  notes.notebook-state
        (~(put by notes.notebook-state) note-id.upd u.nt(title title.upd))
      no-core
    ::
        %note-moved
      =/  nt=(unit note:notes)
        (~(get by notes.notebook-state) note-id.upd)
      ?~  nt  no-core
      =.  notes.notebook-state
        (~(put by notes.notebook-state) note-id.upd u.nt(notebook-id notebook-id.upd, folder-id folder-id.upd))
      no-core
    ::
        %note-deleted
      =.  notes.notebook-state
        (~(del by notes.notebook-state) note-id.upd)
      no-core
    ::
        %note-updated
      =.  notes.notebook-state
        (~(put by notes.notebook-state) id.note.upd note.upd)
      no-core
    ==
  --
--
