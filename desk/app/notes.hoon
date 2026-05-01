::  notes: shared notebook Gall agent (dual-mode host/subscriber)
::
/-  n=notes
/+  default-agent, dbug, verb, notes-json
/=  ui           /lib/notes-ui
/=  share-page   /lib/notes-share
::
|%
+$  card  card:agent:gall
+$  current-state  state-10:n
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
++  dummy  'v0.10.0-type-prefix-n'
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
::  +load: migrate old state to current state-10 via linear per-step chain.
::  Pattern: |^ kelt with =? chain + per-step arms (tloncorp/homestead style).
::
++  load
  |^  |=  =vase
  ^+  cor
  =+  !<(old=any-state vase)
  =?  old  ?=(%1 -.old)  (state-1-to-2 old)
  =?  old  ?=(%2 -.old)  (state-2-to-3 old)
  =?  old  ?=(%3 -.old)  (state-3-to-4 old)
  =?  old  ?=(%4 -.old)  (state-4-to-5 old)
  =?  old  ?=(%5 -.old)  (state-5-to-6 old)
  =?  old  ?=(%6 -.old)  (state-6-to-7 old)
  =?  old  ?=(%7 -.old)  (state-7-to-8 old)
  =?  old  ?=(%8 -.old)  (state-8-to-9 old)
  =?  old  ?=(%9 -.old)  (state-9-to-10 old)
  ?>  ?=(%10 -.old)
  =.  state  old
  cor
  ::
  +$  any-state
    $%  state-10:n
        state-9:n
        state-8:n
        state-7:n
        state-6:n
        state-5:n
        state-4:n
        state-3:n
        state-2:n
        state-1:n
    ==
  ::
  ++  state-1-to-2
    ~>  %spin.['state-1-to-2']
    |=  s=state-1:n
    ^-  state-2:n
    [%2 books.s next-id.s ~]
  ::
  ++  state-2-to-3
    ~>  %spin.['state-2-to-3']
    |=  s=state-2:n
    ^-  state-3:n
    [%3 books.s next-id.s ~]
  ::
  ++  state-3-to-4
    ~>  %spin.['state-3-to-4']
    |=  s=state-3:n
    ^-  state-4:n
    [%4 books.s next-id.s published.s ~]
  ::
  ++  state-4-to-5
    ~>  %spin.['state-4-to-5']
    |=  s=state-4:n
    ^-  state-5:n
    [%5 books.s next-id.s published.s visibilities.s ~]
  ::
  ++  state-5-to-6
    ~>  %spin.['state-5-to-6']
    |=  s=state-5:n
    ^-  state-6:n
    =/  new-invites=(map flag-v9:n invite-info:n)
      %-  ~(run by invites.s)
      |=  ii=invite-info-5:n
      ^-  invite-info:n
      [from.ii sent-at.ii '']
    [%6 books.s next-id.s published.s visibilities.s new-invites]
  ::
  ++  state-6-to-7
    ~>  %spin.['state-6-to-7']
    |=  s=state-6:n
    ^-  state-7:n
    [%7 books.s next-id.s published.s visibilities.s invites.s ~]
  ::
  ++  state-7-to-8
    ~>  %spin.['state-7-to-8']
    |=  s=state-7:n
    ^-  state-8:n
    =/  new-books=(map flag-v9:n [=net:n =notebook-state-v8:n])
      %-  ~(run by books.s)
      |=  [net=net-v0:n old-nbs=notebook-state-v0:n]
      =/  new-nb=notebook:n
        :*  id.notebook.old-nbs  title.notebook.old-nbs
            created-by.notebook.old-nbs  created-at.notebook.old-nbs
            updated-at.notebook.old-nbs  created-by.notebook.old-nbs
        ==
      =/  new-folders=(map @ud folder:n)
        %-  ~(run by folders.old-nbs)
        |=  fld=folder-v0:n
        :*  id.fld  notebook-id.fld  name.fld  parent-folder-id.fld
            created-by.fld  created-at.fld  updated-at.fld  created-by.fld
        ==
      =/  new-net=net:n
        ?-  -.net
          %pub  [%pub *log:n]
          %sub  [%sub time.net init.net]
        ==
      [new-net [new-nb notebook-members.old-nbs new-folders notes.old-nbs]]
    [%8 new-books next-id.s published.s visibilities.s invites.s history.s]
  ::
  ++  state-8-to-9
    ~>  %spin.['state-8-to-9']
    |=  s=state-8:n
    ^-  state-9:n
    =/  new-books=(map flag-v9:n [=net:n =notebook-state:n])
      %-  ~(urn by books.s)
      |=  [f=flag-v9:n [=net:n old-nbs=notebook-state-v8:n]]
      =/  nb-hist=(map @ud (list note-revision:n))
        %-  malt
        %+  murn  ~(tap by history.s)
        |=  [[kf=flag-v9:n nid=@ud] v=(list note-revision:n)]
        ?.  =(kf f)  ~
        `[nid v]
      =/  new-nbs=notebook-state:n
        :*  notebook.old-nbs
            notebook-members.old-nbs
            (fall (~(get by visibilities.s) f) %private)
            folders.old-nbs
            notes.old-nbs
            nb-hist
        ==
      [net new-nbs]
    [%9 new-books next-id.s published.s invites.s]
  ::
  ++  state-9-to-10
    ~>  %spin.['state-9-to-10']
    |=  s=state-9:n
    ^-  state-10:n
    =/  xlat=(map flag-v9:n flag:n)
      %-  malt
      %+  turn  ~(tap by books.s)
      |=  [f=flag-v9:n [=net:n =notebook-state:n]]
      =/  nid=@ud  id.notebook.notebook-state
      =/  new-name=@tas  (slugify title.notebook.notebook-state nid)
      [f [ship.f new-name]]
    =/  new-books=(map flag:n [=net:n =notebook-state:n])
      %-  malt
      %+  turn  ~(tap by books.s)
      |=  [f=flag-v9:n entry=[=net:n =notebook-state:n]]
      =/  nf=flag:n  (~(got by xlat) f)
      [nf entry]
    =/  new-pub=(map [=flag:n note-id=@ud] @t)
      %-  malt
      %+  turn  ~(tap by published.s)
      |=  [[f=flag-v9:n nid=@ud] html=@t]
      =/  nf=flag:n  (fall (~(get by xlat) f) [ship.f `@tas`name.f])
      [[nf nid] html]
    =/  new-invites=(map flag:n invite-info:n)
      %-  malt
      %+  turn  ~(tap by invites.s)
      |=  [f=flag-v9:n info=invite-info:n]
      =/  nf=flag:n  (fall (~(get by xlat) f) [ship.f `@tas`name.f])
      [nf info]
    [%10 new-books next-id.s new-pub new-invites]
  --
::
++  poke
  |=  [=mark =vase]
  ^+  cor
  |^
  ?+  mark  ~|(bad-mark+mark !!)
      %handle-http-request
    (serve-http !<([eyre-id=@ta =inbound-request:eyre] vase))
  ::
      %notes-action
    ::  Actions are local UI requests — they originate from our own ship.
    ::  Cross-ship messages (host → invitee notify-invite, subscriber →
    ::  host commands) flow via %notes-command instead.
    ?>  =(our.bowl src.bowl)
    =+  !<(act=action:n vase)
    ::  top-level actions handled without notebook flag
    ?:  ?=(%create-notebook -.act)
      se-abet:(se-create-notebook:(se-init:se-core act) act)
    ?:  ?=(%join -.act)
      (join-remote flag.act)
    ?:  ?=(%leave -.act)
      (leave-remote flag.act)
    ?:  ?=(%accept-invite -.act)
      (handle-accept-invite flag.act)
    ?:  ?=(%decline-invite -.act)
      (handle-decline-invite flag.act)
    ::  all other actions are notebook-scoped: [%notebook =flag =a-notebook]
    ?>  ?=(%notebook -.act)
    =/  =flag:n  flag.act
    =/  nb-act=a-notebook:n  a-notebook.act
    ::  %invite: owner sends invite to a ship — handled locally
    ?:  ?=(%invite -.nb-act)
      (handle-send-invite flag who.nb-act)
    ::  %note [%publish]/[%unpublish]: local-only, not forwarded to remote hosts
    ?:  ?=(%note -.nb-act)
      =/  nid=@ud  id.nb-act
      =/  n-act=a-note:n  a-note.nb-act
      ?:  ?=(%publish -.n-act)
        =.  published.state  (~(put by published.state) [flag nid] html.n-act)
        cor
      ?:  ?=(%unpublish -.n-act)
        =.  published.state  (~(del by published.state) [flag nid])
        cor
      ::  all other note actions: route to se/no core
      =/  entry=[=net:n =notebook-state:n]
        (~(got by books.state) flag)
      ?:  ?=(%pub -.net.entry)
        se-abet:(se-poke:(se-abed:se-core flag) [flag (a-notebook-to-c-notebook nb-act)])
      no-abet:(no-action:(no-abed:no-core flag) act)
    ::  all other notebook actions: route to se/no core
    =/  entry=[=net:n =notebook-state:n]
      (~(got by books.state) flag)
    ?:  ?=(%pub -.net.entry)
      se-abet:(se-poke:(se-abed:se-core flag) [flag (a-notebook-to-c-notebook nb-act)])
    no-abet:(no-action:(no-abed:no-core flag) act)
  ::
      %notes-command
    =+  !<(cmd=command:n vase)
    ?-    -.cmd
        %notify-invite
      ::  Cross-ship invite delivery — src.bowl validation lives in
      ::  handle-notify-invite (must equal ship.flag, the inviting host).
      (handle-notify-invite flag.cmd title.cmd src.bowl)
    ::
        %notebook
      =/  =flag:n  flag.cmd
      ::  member-join/-leave: any ship can request membership change on
      ::  a notebook we host; se-member-join/-leave enforces visibility
      ::  + role logic. All other commands assume the sender is already
      ::  a member; se-poke arms re-check via se-can-edit/se-is-owner.
      ?>  =(ship.flag our.bowl)
      ?>  (~(has by books.state) flag)
      se-abet:(se-poke:(se-abed:se-core flag) [flag c-notebook.cmd])
    ==
  ==
  ::
  ::  +join-remote: initiate joining a notebook on a remote ship
  ++  join-remote
    |=  =flag:n
    ^+  cor
    ?<  =(our.bowl ship.flag)
    ?<  (~(has by books.state) flag)
    =/  placeholder-net=net:n  [%sub *@da |]
    =/  placeholder-nb=notebook:n
      [0 '' ship.flag *@da *@da ship.flag]
    =/  placeholder-nb-state=notebook-state:n
      [placeholder-nb ~ %private ~ ~ ~]
    =.  books.state
      (~(put by books.state) flag [placeholder-net placeholder-nb-state])
    ::  send %member-join command to host (wrapped in c-notes %notebook arm)
    %-  emit
    :+  %pass
      /notes/join/(scot %p ship.flag)/[name.flag]
    [%agent [ship.flag %notes] %poke notes-command+!>(`command:n`[%notebook flag [%member-join ~]])]
  ::
  ::  +leave-remote: leave a notebook on a remote ship
  ++  leave-remote
    |=  =flag:n
    ^+  cor
    ?>  (~(has by books.state) flag)
    no-abet:no-leave:(no-abed:no-core flag)
  ::
  ::  +handle-send-invite: owner-only, fired locally. Pre-add the target ship
  ::  to the notebook's member list and notify their %notes agent.
  ++  handle-send-invite
    |=  [=flag:n who=ship]
    ^+  cor
    ?>  =(ship.flag our.bowl)
    =/  entry=[=net:n =notebook-state:n]
      (~(got by books.state) flag)
    =/  title=@t  title.notebook.notebook-state.entry
    ::  pre-add via se-core (also enforces ownership)
    =.  cor
      =/  cmd=c-cmd:n  [flag [%invite who]]
      se-abet:(se-poke:(se-abed:se-core flag) cmd)
    ::  Poke the invitee's notes agent with %notify-invite as a c-notes
    ::  command — actions are local-only (src must equal our), so cross-
    ::  ship invite delivery flows through the command surface. The arm
    ::  carries the notebook title so the inbox can render it pre-join.
    %-  emit
    :+  %pass
      /notes/invite/(scot %p who)/(scot %p ship.flag)/[name.flag]
    [%agent [who %notes] %poke notes-command+!>(`command:n`[%notify-invite flag title])]
  ::
  ::  +handle-notify-invite: called when a remote host pokes us with
  ::  [%notify-invite flag title]. The sender must be the notebook host.
  ++  handle-notify-invite
    |=  [=flag:n title=@t from=ship]
    ^+  cor
    ?<  =(from our.bowl)
    ?>  =(from ship.flag)
    ?:  (~(has by books.state) flag)  cor
    ?:  (~(has by invites.state) flag)  cor
    =/  info=invite-info:n  [from now.bowl title]
    =.  invites.state  (~(put by invites.state) flag info)
    (give-inbox-received flag from now.bowl title)
  ::
  ::  +handle-accept-invite: user accepted a pending invite
  ++  handle-accept-invite
    |=  =flag:n
    ^+  cor
    ?>  =(src.bowl our.bowl)
    =.  invites.state  (~(del by invites.state) flag)
    =.  cor  (give-inbox-removed flag)
    ?:  (~(has by books.state) flag)  cor
    (join-remote flag)
  ::
  ::  +handle-decline-invite: user declined a pending invite
  ++  handle-decline-invite
    |=  =flag:n
    ^+  cor
    ?>  =(src.bowl our.bowl)
    ?.  (~(has by invites.state) flag)  cor
    =.  invites.state  (~(del by invites.state) flag)
    (give-inbox-removed flag)
  --
::
::  +serve-http: dispatch an HTTP request to the right responder.
::  Order: PWA static assets → published note → share redirect → UI fallback.
++  serve-http
  |=  [eyre-id=@ta =inbound-request:eyre]
  ^+  cor
  =/  url-tape=tape  (trip url.request.inbound-request)
  =/  url-path=tape  (strip-query url-tape)
  ::  PWA-related static assets: manifest, service worker, icons.
  ::  Each returns [body content-type] or ~. Served scoped under
  ::  /notes/ so the SW can control the app's URL space.
  =/  asset=(unit [body=@t ct=@t])
    ?:  =("/notes/manifest.json" url-path)
      `[manifest:ui 'application/manifest+json']
    ?:  =("/notes/sw.js" url-path)
      ::  text/javascript is required by some browsers for SW registration.
      `[service-worker:ui 'text/javascript']
    ?:  =("/notes/icon.svg" url-path)
      `[icon-svg:ui 'image/svg+xml']
    ?:  =("/notes/favicon.svg" url-path)
      `[favicon-svg:ui 'image/svg+xml']
    ~
  ::  /notes/pub/~ship/name/{note-id} → serve archived published HTML
  =/  pub-html=(unit @t)
    ?.  =("/notes/pub/" (scag 11 url-tape))  ~
    =/  path-only=tape  (strip-query (slag 11 url-tape))
    =/  pax=path  (stab (crip (weld "/" path-only)))
    ?.  ?=([@ @ @ ~] pax)  ~
    ?~  ship-u=(slaw %p i.pax)  ~
    ?~  nid-u=(slaw %ud i.t.t.pax)  ~
    ?:  =(0 u.nid-u)  ~
    =/  =flag:n  [u.ship-u `@tas`i.t.pax]
    (~(get by published.state) [flag u.nid-u])
  ::  /notes/share/~ship/name → serve the share-redirect page
  =/  share-html=(unit @t)
    ?.  =("/notes/share/" (scag 13 url-tape))  ~
    =/  path-only=tape  (strip-query (slag 13 url-tape))
    =/  pax=path  (stab (crip (weld "/" path-only)))
    ?.  ?=([@ @ ~] pax)  ~
    ?~  (slaw %p i.pax)  ~
    `share-page
  =/  body=@t
    ?^  asset       body.u.asset
    ?^  pub-html    u.pub-html
    ?^  share-html  u.share-html
    index:ui
  =/  ct=@t
    ?^  asset  ct.u.asset
    'text/html'
  =/  data=octs  [(met 3 body) body]
  =/  =response-header:http  [200 ~[['content-type' ct]]]
  %-  emil
  :~  [%give %fact [/http-response/[eyre-id]]~ %http-response-header !>(response-header)]
      [%give %fact [/http-response/[eyre-id]]~ %http-response-data !>(`data)]
      [%give %kick [/http-response/[eyre-id]]~ ~]
  ==
::
++  watch
  |=  =(pole knot)
  ^+  cor
  ?+  pole  ~|(bad-watch-path+pole !!)
      [%http-response *]
    cor
  ::
      [%v0 %notes ship=@ name=@ %updates ~]
    ::  remote subscriber watching our hosted notebook's update stream
    =/  =flag:n  [(slav %p ship.pole) `@tas`name.pole]
    ?>  =(our.bowl ship.flag)
    se-abet:se-watch:(se-abed:se-core flag)
  ::
      [%v0 %notes ship=@ name=@ %stream ~]
    ::  local UI subscription for any notebook (pub or sub)
    =/  =flag:n  [(slav %p ship.pole) `@tas`name.pole]
    no-abet:no-watch:(no-abed:no-core flag)
  ::
      [%v0 %inbox %stream ~]
    ?>  =(src.bowl our.bowl)
    cor
  ==
::
++  peek
  |=  =(pole knot)
  ^-  (unit (unit cage))
  ?+  pole  ~
    ::  /x/ui — serve the frontend
      [%x %ui ~]
    ``html+!>(index:ui)
    ::  /x/v0/notebooks — list all notebooks (cross-cutting, no flag)
      [%x %v0 %notebooks ~]
    =/  nbs=(list json)
      %+  murn  ~(tap by books.state)
      |=  [=flag:n [=net:n =notebook-state:n]]
      ?.  (can-view-flag flag src.bowl)  ~
      =-  `(pairs:enjs:format -)
      :~  ['host' s+(scot %p ship.flag)]
          ['flagName' s+name.flag]
          ['notebook' (notebook:enjs:notes-json notebook.notebook-state)]
          ['visibility' s+(scot %tas visibility.notebook-state)]
      ==
    ``json+!>([%a nbs])
    ::  /x/v0/published — list of {host, flagName, noteId} for each published note
      [%x %v0 %published ~]
    =/  items=(list json)
      %+  turn  ~(tap in ~(key by published.state))
      |=  [=flag:n note-id=@ud]
      %-  pairs:enjs:format
      :~  ['host' s+(scot %p ship.flag)]
          ['flagName' s+name.flag]
          ['noteId' (numb:enjs:format note-id)]
      ==
    ``json+!>([%a items])
    ::  /x/v0/invites — pending invites we've received
      [%x %v0 %invites ~]
    =/  items=(list json)
      %+  turn  ~(tap by invites.state)
      |=  [=flag:n info=invite-info:n]
      %-  pairs:enjs:format
      :~  ['host' s+(scot %p ship.flag)]
          ['flagName' s+name.flag]
          ['from' s+(scot %p from.info)]
          ['sentAt' (numb:enjs:format (div (sub sent-at.info ~1970.1.1) ~s1))]
          ['title' s+title.info]
      ==
    ``json+!>([%a items])
    ::  /x/debug/dummy — current ++dummy value for tooling readiness checks
      [%x %debug %dummy ~]
    ``json+!>(s+dummy)
    ::  /x/v0/<kind>/<ship>/<name>[/<rest>] — delegate to no-peek
      [%x %v0 kind=@ ship=@ name=@ rest=*]
    =/  =flag:n  [(slav %p ship.pole) `@tas`name.pole]
    ?~  (~(get by books.state) flag)  ``json+!>(~)
    (no-peek:(no-abed:no-core flag) kind.pole rest.pole)
  ==
::
++  agent
  |=  [=(pole knot) =sign:agent:gall]
  ^+  cor
  ?+  pole  ~|(bad-agent-wire+pole !!)
      [%notes %sub ship=@ name=@ ~]
    =/  =flag:n
      [(slav %p ship.pole) `@tas`name.pole]
    ?.  (~(has by books.state) flag)
      cor
    no-abet:(no-agent:(no-abed:no-core flag) sign)
  ::
      [%notes %join ship=@ name=@ ~]
    =/  =flag:n
      [(slav %p ship.pole) `@tas`name.pole]
    ?+  -.sign  cor
        %poke-ack
      ?~  p.sign
        ::  poke succeeded — host has added us, now subscribe
        no-abet:no-start-watch:(no-abed:no-core flag)
      ::  poke failed — remove placeholder from books
      =.  books.state  (~(del by books.state) flag)
      cor
    ==
  ::
      [%notes %invite who=@ ship=@ name=@ ~]
    ?+  -.sign  cor
        %poke-ack  cor
    ==
  ==
::
++  arvo
  |=  [=wire =sign-arvo]
  ^+  cor
  ?+  sign-arvo  ~|(bad-arvo-sign+wire !!)
    [%eyre %bound *]  cor
  ==
::
::  ====  utility arms  ====
::
::  +slugify: convert a title cord + numeric suffix into a valid @tas term.
::  Algorithm:
::  1. Lowercase all chars; map non-[a-z0-9] to '-'
::  2. Collapse consecutive '-' into one
::  3. Trim leading and trailing '-'
::  4. Cap at 32 chars
::  5. Default to "note" if empty
::  6. Prefix "n-" if first char is a digit
::  7. Append "-{suffix}" (strip dots from scot %ud output)
++  slugify
  |=  [t=@t suffix=@ud]
  ^-  @tas
  =/  chars=tape  (trip t)
  ::  step 1: map each char to lowercase letter, digit, or '-'
  =/  mapped=tape
    %+  turn  chars
    |=  c=@t
    ^-  @t
    ?:  &((gte c 'a') (lte c 'z'))  c
    ?:  &((gte c 'A') (lte c 'Z'))  (add c 32)
    ?:  &((gte c '0') (lte c '9'))  c
    '-'
  ::  step 2: collapse consecutive '-' into one
  =/  collapsed=tape
    %-  flop
    =|  acc=tape
    |-  ^+  acc
    ?~  mapped  acc
    ?:  &(=('-' i.mapped) ?=(^ acc) =('-' i.acc))
      $(mapped t.mapped)
    $(mapped t.mapped, acc [i.mapped acc])
  ::  step 3: trim leading '-'
  =/  ltrimmed=tape
    |-  ^-  tape
    ?~  collapsed  ~
    ?:  =('-' i.collapsed)
      $(collapsed t.collapsed)
    collapsed
  ::  step 3b: trim trailing '-'
  =/  trimmed=tape
    =/  rev=tape  (flop ltrimmed)
    =/  rtrimmed=tape
      |-  ^-  tape
      ?~  rev  ~
      ?:  =('-' i.rev)
        $(rev t.rev)
      rev
    (flop rtrimmed)
  ::  step 4: cap at 32 chars
  =/  capped=tape  (scag 32 trimmed)
  ::  step 5: default to "note" if empty
  =/  base=tape  ?~(capped "note" capped)
  ::  step 6: prefix "n-" if first char is a digit
  =/  prefixed=tape
    ?.  &(?=(^ base) (gte i.base '0') (lte i.base '9'))
      base
    (weld "n-" base)
  ::  step 7: build suffix string (strip dots from scot %ud)
  =/  raw-suf=tape  (trip (scot %ud suffix))
  =/  suf-tape=tape
    %+  skim  raw-suf
    |=(c=@t !=(c '.'))
  =/  slug=tape  (weld (weld prefixed "-") suf-tape)
  `@tas`(crip slug)
::
::  +a-notebook-to-c-notebook: convert a-notebook to c-notebook (same shape except %restore)
::  %restore is rewritten to %note [id %update] with the archived body
++  a-notebook-to-c-notebook
  |=  nb-act=a-notebook:n
  ^-  c-notebook:n
  ::  a-notebook and c-notebook have identical shapes (c-notebook adds
  ::  %member-join/%member-leave which only arrive via %notes-command, never
  ::  via %notes-action from the client). Direct cast works for all a-notebook arms.
  ;;(c-notebook:n nb-act)
::
::  +get-book: lookup a notebook entry by flag
++  get-book
  |=  =flag:n
  ^-  (unit [=net:n =notebook-state:n])
  (~(get by books.state) flag)
::
::  +strip-query: drop any query string from a URL tape (returns path portion only)
++  strip-query
  |=  url=tape
  ^-  tape
  =/  qi=(unit @ud)  (find "?" url)
  ?~  qi  url
  (scag u.qi url)
::
::  +can-view-flag: check if ship can view a notebook by flag
++  can-view-flag
  |=  [=flag:n who=ship]
  ^-  ?
  ?~  entry=(get-book flag)  |
  =/  mbrs=members:n
    members.notebook-state.u.entry
  ?~  (~(get by mbrs) who)  |
  &
::
::  +find-flag-by-nid: find the flag for a notebook by numeric notebook id
++  find-flag-by-nid
  |=  nid=@ud
  ^-  flag:n
  =/  matches=(list flag:n)
    %+  murn  ~(tap by books.state)
    |=  [=flag:n [=net:n =notebook-state:n]]
    ?:  =(nid id.notebook.notebook-state)
      `flag
    ~
  ?~  matches  ~|(notebook-not-found+nid !!)
  i.matches
::
::  +notebooks-changed-card: a fact telling subscribed UIs to re-scry notebooks
++  notebooks-changed-card
  ^-  card
  =/  evt=json
    (pairs:enjs:format ~[['type' s+'notebooks-changed']])
  [%give %fact [/v0/inbox/stream]~ json+!>((pairs:enjs:format ~[['type' s+'update'] ['update' evt]]))]
::
::  +give-inbox-received: emit an invite-received event on /v0/inbox/stream
++  give-inbox-received
  |=  [=flag:n from=ship sent-at=@da title=@t]
  ^+  cor
  =/  evt=json
    %-  pairs:enjs:format
    :~  ['type' s+'invite-received']
        ['host' s+(scot %p ship.flag)]
        ['flagName' s+name.flag]
        ['from' s+(scot %p from)]
        ['sentAt' (numb:enjs:format (div (sub sent-at ~1970.1.1) ~s1))]
        ['title' s+title]
    ==
  %-  give
  [%fact [/v0/inbox/stream]~ json+!>((pairs:enjs:format ~[['type' s+'update'] ['update' evt]]))]
::
::  +give-inbox-removed: emit an invite-removed event on /v0/inbox/stream
++  give-inbox-removed
  |=  =flag:n
  ^+  cor
  =/  evt=json
    %-  pairs:enjs:format
    :~  ['type' s+'invite-removed']
        ['host' s+(scot %p ship.flag)]
        ['flagName' s+name.flag]
    ==
  %-  give
  [%fact [/v0/inbox/stream]~ json+!>((pairs:enjs:format ~[['type' s+'update'] ['update' evt]]))]
::
::  ====  se-core: server/host core  ====
::
++  se-core
  |_  [=flag:n =log:n =notebook-state:n gone=_|]
  ++  se-core  .
  ++  emit  |=(=card se-core(cor cor(cards [card cards])))
  ++  give  |=(=gift:agent:gall (emit %give gift))
  ::
  ::  +se-init: initialize for a brand-new notebook
  ++  se-init
    |=  act=action:n
    ^+  se-core
    ?>  ?=(%create-notebook -.act)
    =/  nid=@ud  +(next-id.state)
    =/  =flag:n  [our.bowl (slugify title.act nid)]
    se-core(flag flag)
  ::
  ::  +se-abed: load from state for a given flag
  ++  se-abed
    |=  f=flag:n
    ^+  se-core
    ?>  =(ship.f our.bowl)
    ?~  entry=(~(get by books.state) f)
      ~|(se-abed-not-found+f !!)
    =/  [=net:n =notebook-state:n]  u.entry
    ?>  ?=(%pub -.net)
    se-core(flag f, log log.net, notebook-state notebook-state)
  ::
  ::  +se-abet: write back to cor
  ++  se-abet
    ^+  cor
    =.  books.state
      ?:  gone
        (~(del by books.state) flag)
      (~(put by books.state) flag [[%pub log] notebook-state])
    cor
  ::
  ++  se-area
    `path`/v0/notes/(scot %p ship.flag)/[name.flag]
  ::
  ++  se-sub-path
    `path`(weld se-area /updates)
  ::
  ::  +se-update: append update to log and broadcast to subscribers
  ++  se-update
    |=  upd=u-notebook:n
    ^+  se-core
    =/  ts=@da
      |-
      ?~  existing=(get:log-on:n log now.bowl)  now.bowl
      $(now.bowl `@da`(add now.bowl ^~((div ~s1 (bex 16)))))
    =.  log  (put:log-on:n log [ts upd])
    %-  give
    :+  %fact  ~[se-sub-path (weld se-area /stream)]
    notes-response+!>(`response:n`[%update flag [ts upd]])
  ::
  ::  +se-watch-sub: send initial snapshot to a new subscriber (with visibility)
  ++  se-watch-sub
    |=  who=ship
    ^+  se-core
    %-  give
    [%fact ~ notes-response+!>(`response:n`[%snapshot flag visibility.notebook-state notebook-state])]
  ::
  ::  +se-watch: handle remote-subscriber watch (dispatch from top-level +watch)
  ++  se-watch
    ^+  se-core
    ?>  =(our.bowl ship.flag)
    ?>  (se-can-view src.bowl)
    (se-watch-sub src.bowl)
  ::
  ++  se-can-view
    |=  who=ship
    ^-  ?
    ?~  (~(get by members.notebook-state) who)  |
    &
  ::
  ++  se-can-edit
    |=  who=ship
    ^-  ?
    =/  r=(unit role:n)
      (~(get by members.notebook-state) who)
    ?~  r  |
    ?|  =(u.r %owner)
        =(u.r %editor)
    ==
  ::
  ++  se-is-owner
    |=  who=ship
    ^-  ?
    =/  r=(unit role:n)
      (~(get by members.notebook-state) who)
    ?~  r  |
    =(u.r %owner)
  ::
  ++  se-visibility
    ^-  visibility:n
    visibility.notebook-state
  ::
  ::  +se-create-notebook: handle %create-notebook action
  ::  nid is +(next-id.state) — same value se-init used to build the flag slug;
  ::  state has not been modified between se-init and this call.
  ++  se-create-notebook
    |=  act=action:n
    ?>  ?=(%create-notebook -.act)
    ^+  se-core
    =/  nid=@ud  +(next-id.state)
    =/  rfid=@ud  +(nid)
    =/  nb=notebook:n
      [nid title.act our.bowl now.bowl now.bowl our.bowl]
    =/  nb-state=notebook-state:n
      :*  nb
          (~(put by *members:n) our.bowl %owner)
          %private
          (~(put by *(map @ud folder:n)) rfid [rfid nid '/' ~ our.bowl now.bowl now.bowl our.bowl])
          ~
          ~
      ==
    =.  next-id.state  rfid
    =.  notebook-state  nb-state
    =.  books.state
      (~(put by books.state) flag [[%pub *log:n] notebook-state])
    =.  se-core  (emit notebooks-changed-card)
    (se-update [%created nb %private])
  ::
  ::  +se-poke: dispatch a c-notes command to the right handler
  ++  se-poke
    |=  cmd=c-cmd:n
    ^+  se-core
    ?-  -.c-notebook.cmd
        %rename            (se-rename-notebook cmd)
        %delete            (se-delete-notebook cmd)
        %visibility        (se-set-visibility cmd)
        %invite            (se-invite cmd)
        %create-folder     (se-create-folder cmd)
        %folder            (se-dispatch-folder cmd)
        %create-note       (se-create-note cmd)
        %note              (se-dispatch-note cmd)
        %batch-import      (se-batch-import cmd)
        %batch-import-tree  (se-batch-import-tree cmd)
        %member-join       (se-member-join cmd)
        %member-leave      (se-member-leave cmd)
    ==
  ::
  ++  se-rename-notebook
    |=  cmd=c-cmd:n
    ?>  ?=(%rename -.c-notebook.cmd)
    ^+  se-core
    ?>  (se-is-owner src.bowl)
    =/  nb=notebook:n  notebook.notebook-state
    =.  nb  nb(title title.c-notebook.cmd, updated-at now.bowl, updated-by src.bowl)
    =.  notebook.notebook-state  nb
    (se-update [%updated nb])
  ::
  ++  se-delete-notebook
    |=  cmd=c-cmd:n
    ?>  ?=(%delete -.c-notebook.cmd)
    ^+  se-core
    ?>  (se-is-owner src.bowl)
    ::  clean up published entries for this notebook
    =.  published.state
      %-  malt
      %+  skip  ~(tap by published.state)
      |=  [k=[=flag:n note-id=@ud] v=@t]
      =(flag.k flag)
    ::  history and visibility live in notebook-state, deleted via gone flag
    =.  se-core  (se-update [%deleted ~])
    se-core(gone &)
  ::
  ++  se-set-visibility
    |=  cmd=c-cmd:n
    ?>  ?=(%visibility -.c-notebook.cmd)
    ^+  se-core
    ?>  (se-is-owner src.bowl)
    =.  visibility.notebook-state  visibility.c-notebook.cmd
    (se-update [%visibility visibility.c-notebook.cmd])
  ::
  ++  se-invite
    |=  cmd=c-cmd:n
    ?>  ?=(%invite -.c-notebook.cmd)
    ^+  se-core
    ?>  (se-is-owner src.bowl)
    =/  who=ship  who.c-notebook.cmd
    ?:  (~(has by members.notebook-state) who)
      se-core
    =.  members.notebook-state
      (~(put by members.notebook-state) who %editor)
    (se-update [%member-joined who %editor])
  ::
  ++  se-member-join
    |=  cmd=c-cmd:n
    ?>  ?=(%member-join -.c-notebook.cmd)
    ^+  se-core
    ::  private notebooks reject joins from non-members
    ?:  ?&  =(%private se-visibility)
            !(se-can-view src.bowl)
        ==
      ~|(notebook-private+flag !!)
    =.  members.notebook-state
      (~(put by members.notebook-state) src.bowl %editor)
    (se-update [%member-joined src.bowl %editor])
  ::
  ++  se-member-leave
    |=  cmd=c-cmd:n
    ?>  ?=(%member-leave -.c-notebook.cmd)
    ^+  se-core
    =.  members.notebook-state
      (~(del by members.notebook-state) src.bowl)
    (se-update [%member-left src.bowl])
  ::
  ++  se-dispatch-folder
    |=  cmd=c-cmd:n
    ?>  ?=(%folder -.c-notebook.cmd)
    ^+  se-core
    =/  fid=@ud  id.c-notebook.cmd
    =/  fld-act=a-folder:n  a-folder.c-notebook.cmd
    ?-  -.fld-act
      %rename  (se-rename-folder cmd)
      %move    (se-move-folder cmd)
      %delete  (se-delete-folder cmd)
    ==
  ::
  ++  se-dispatch-note
    |=  cmd=c-cmd:n
    ?>  ?=(%note -.c-notebook.cmd)
    ^+  se-core
    =/  n-act=a-note:n  a-note.c-notebook.cmd
    ?-  -.n-act
      %rename   (se-rename-note cmd)
      %move     (se-move-note cmd)
      %delete   (se-delete-note cmd)
      %update   (se-update-note cmd)
      %publish  se-core  ::  handled pre-dispatch (local-only)
      %unpublish  se-core
      %restore  (se-restore-note cmd)
    ==
  ::
  ++  se-create-folder
    |=  cmd=c-cmd:n
    ?>  ?=(%create-folder -.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  parent=(unit @ud)  parent.c-notebook.cmd
    =/  fid=@ud  +(next-id.state)
    =.  next-id.state  fid
    =/  nid=@ud  id.notebook.notebook-state
    =/  nf=folder:n
      [fid nid name.c-notebook.cmd parent src.bowl now.bowl now.bowl src.bowl]
    =.  folders.notebook-state
      (~(put by folders.notebook-state) fid nf)
    (se-update [%folder fid [%created nf]])
  ::
  ++  se-rename-folder
    |=  cmd=c-cmd:n
    ?>  ?=(%folder -.c-notebook.cmd)
    ?>  ?=(%rename -.a-folder.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  fid=@ud  id.c-notebook.cmd
    =/  fld=folder:n
      (~(got by folders.notebook-state) fid)
    =.  fld  fld(name name.a-folder.c-notebook.cmd, updated-at now.bowl, updated-by src.bowl)
    =.  folders.notebook-state
      (~(put by folders.notebook-state) fid fld)
    (se-update [%folder fid [%updated fld]])
  ::
  ++  se-move-folder
    |=  cmd=c-cmd:n
    ?>  ?=(%folder -.c-notebook.cmd)
    ?>  ?=(%move -.a-folder.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  fid=@ud  id.c-notebook.cmd
    =/  new-parent=@ud  new-parent.a-folder.c-notebook.cmd
    =/  fld=folder:n
      (~(got by folders.notebook-state) fid)
    =/  subtree=(set @ud)
      (se-subtree-folder-ids fid)
    ?<  (~(has in subtree) new-parent)
    =.  fld  fld(parent-folder-id `new-parent, updated-at now.bowl, updated-by src.bowl)
    =.  folders.notebook-state
      (~(put by folders.notebook-state) fid fld)
    (se-update [%folder fid [%updated fld]])
  ::
  ++  se-delete-folder
    |=  cmd=c-cmd:n
    ?>  ?=(%folder -.c-notebook.cmd)
    ?>  ?=(%delete -.a-folder.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  fid=@ud  id.c-notebook.cmd
    =/  recursive=?  recursive.a-folder.c-notebook.cmd
    =/  fld=folder:n
      (~(got by folders.notebook-state) fid)
    ?>  ?=(^ parent-folder-id.fld)
    ?:  recursive
      =/  del-fids=(set @ud)
        (se-subtree-folder-ids fid)
      =/  del-nids=(set @ud)
        (se-note-ids-in-folder-set del-fids)
      =.  folders.notebook-state
        %-  ~(rep in del-fids)
        |=  [f=@ud acc=_folders.notebook-state]
        (~(del by acc) f)
      =.  notes.notebook-state
        %-  ~(rep in del-nids)
        |=  [n=@ud acc=_notes.notebook-state]
        (~(del by acc) n)
      (se-update [%folder fid [%deleted ~]])
    ::  non-recursive: fail if has children
    =/  children=(list @ud)
      (se-folder-children-ids fid)
    ?>  =(~ children)
    =/  child-notes=(list note:n)
      (se-notes-in-folder fid)
    ?>  =(~ child-notes)
    =.  folders.notebook-state
      (~(del by folders.notebook-state) fid)
    (se-update [%folder fid [%deleted ~]])
  ::
  ++  se-create-note
    |=  cmd=c-cmd:n
    ?>  ?=(%create-note -.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  nid-nb=@ud  id.notebook.notebook-state
    =/  fid=@ud  folder.c-notebook.cmd
    =/  fld=folder:n
      (~(got by folders.notebook-state) fid)
    =/  nid=@ud  +(next-id.state)
    =.  next-id.state  nid
    =/  nt=note:n
      :*  nid
          nid-nb
          fid
          title.c-notebook.cmd
          ~
          body.c-notebook.cmd
          src.bowl
          now.bowl
          src.bowl
          now.bowl
          0
      ==
    =.  notes.notebook-state
      (~(put by notes.notebook-state) nid nt)
    (se-update [%note nid [%created nt]])
  ::
  ++  se-rename-note
    |=  cmd=c-cmd:n
    ?>  ?=(%note -.c-notebook.cmd)
    ?>  ?=(%rename -.a-note.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  nid=@ud  id.c-notebook.cmd
    =/  nt=note:n  (~(got by notes.notebook-state) nid)
    ::  Title changes do NOT bump revision. The revision counter tracks
    ::  body-md only — that's what optimistic concurrency on update-note
    ::  cares about. Bumping rev on rename silently desynced auto-save
    ::  (which sends body+rename back-to-back) by leaving the server at
    ::  rev+1 while the client believed it was still at rev.
    =.  nt
      %_  nt
        title       title.a-note.c-notebook.cmd
        updated-by  src.bowl
        updated-at  now.bowl
      ==
    =.  notes.notebook-state
      (~(put by notes.notebook-state) nid nt)
    (se-update [%note nid [%updated nt]])
  ::
  ++  se-move-note
    |=  cmd=c-cmd:n
    ?>  ?=(%note -.c-notebook.cmd)
    ?>  ?=(%move -.a-note.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  nid=@ud  id.c-notebook.cmd
    =/  nt=note:n  (~(got by notes.notebook-state) nid)
    =/  new-fid=@ud  folder.a-note.c-notebook.cmd
    ::  Move does NOT bump revision; same reasoning as rename — body-md
    ::  is the only field that drives optimistic concurrency.
    =.  nt
      %_  nt
        folder-id   new-fid
        updated-by  src.bowl
        updated-at  now.bowl
      ==
    =.  notes.notebook-state
      (~(put by notes.notebook-state) nid nt)
    (se-update [%note nid [%updated nt]])
  ::
  ++  se-delete-note
    |=  cmd=c-cmd:n
    ?>  ?=(%note -.c-notebook.cmd)
    ?>  ?=(%delete -.a-note.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  nid=@ud  id.c-notebook.cmd
    =/  nt=note:n
      (~(got by notes.notebook-state) nid)
    =.  notes.notebook-state
      (~(del by notes.notebook-state) nid)
    (se-update [%note nid [%deleted ~]])
  ::
  ++  se-update-note
    |=  cmd=c-cmd:n
    ?>  ?=(%note -.c-notebook.cmd)
    ?>  ?=(%update -.a-note.c-notebook.cmd)
    ^+  se-core
    =/  nid=@ud  id.c-notebook.cmd
    =/  nt=note:n
      (~(got by notes.notebook-state) nid)
    ?>  (se-can-edit src.bowl)
    ::  strict optimistic concurrency check (no force-update sentinel)
    ?:  !=(revision.nt expected-revision.a-note.c-notebook.cmd)
      ~|(%revision-mismatch !!)
    ::  no-op early-out: body unchanged
    ?:  =(body-md.nt body.a-note.c-notebook.cmd)
      se-core
    ::  archive the prior revision into per-notebook history
    =/  prior=note-revision:n
      :*  rev=revision.nt
          at=now.bowl
          author=src.bowl
          title=title.nt
          body-md=body-md.nt
      ==
    =/  existing=(list note-revision:n)
      (fall (~(get by history.notebook-state) nid) ~)
    =.  history.notebook-state
      (~(put by history.notebook-state) nid [prior existing])
    =.  nt
      %_  nt
        body-md     body.a-note.c-notebook.cmd
        updated-by  src.bowl
        updated-at  now.bowl
        revision    +(revision.nt)
      ==
    =.  notes.notebook-state
      (~(put by notes.notebook-state) nid nt)
    ::  emit archive event first, then update
    =.  se-core
      (se-update [%note nid [%history-archived prior]])
    (se-update [%note nid [%updated nt]])
  ::
  ::  +se-restore-note: revert to a prior archived revision
  ::  This is simply an update with the archived body, respecting current revision.
  ++  se-restore-note
    |=  cmd=c-cmd:n
    ?>  ?=(%note -.c-notebook.cmd)
    ?>  ?=(%restore -.a-note.c-notebook.cmd)
    ^+  se-core
    =/  nid=@ud  id.c-notebook.cmd
    =/  target-rev=@ud  rev.a-note.c-notebook.cmd
    =/  nt=note:n
      (~(got by notes.notebook-state) nid)
    ?>  (se-can-edit src.bowl)
    ::  find the archived revision in per-notebook history
    =/  revs=(list note-revision:n)
      (fall (~(get by history.notebook-state) nid) ~)
    =/  found=(unit note-revision:n)
      |-
      ?~  revs  ~
      ?:  =(rev.i.revs target-rev)
        `i.revs
      $(revs t.revs)
    ?>  ?=(^ found)
    ::  apply as a normal update with current revision as expected
    (se-update-note `c-cmd:n`[flag [%note nid [%update body-md.u.found revision.nt]]])
  ::
  ++  se-batch-import
    |=  cmd=c-cmd:n
    ?>  ?=(%batch-import -.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  items=(list [title=@t body=@t])  notes.c-notebook.cmd
    =/  nid-nb=@ud  id.notebook.notebook-state
    =/  fid=@ud  folder.c-notebook.cmd
    |-  ^+  se-core
    ?~  items  se-core
    =/  nid=@ud  +(next-id.state)
    =.  next-id.state  nid
    =/  nt=note:n
      :*  nid
          nid-nb
          fid
          title.i.items
          ~
          body.i.items
          src.bowl
          now.bowl
          src.bowl
          now.bowl
          0
      ==
    =.  notes.notebook-state
      (~(put by notes.notebook-state) nid nt)
    =.  se-core  (se-update [%note nid [%created nt]])
    $(items t.items, se-core se-core)
  ::
  ++  se-batch-import-tree
    |=  cmd=c-cmd:n
    ?>  ?=(%batch-import-tree -.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  items=(list import-node:n)  tree.c-notebook.cmd
    =/  nid-nb=@ud  id.notebook.notebook-state
    =|  stack=(list [remaining=(list import-node:n) folder-id=@ud])
    =/  fid=@ud  parent.c-notebook.cmd
    |-  ^+  se-core
    ?~  items
      ?~  stack
        se-core
      $(items remaining.i.stack, fid folder-id.i.stack, stack t.stack)
    ?-  -.i.items
        %note
      =/  nid=@ud  +(next-id.state)
      =.  next-id.state  nid
      =/  nt=note:n
        :*  nid
            nid-nb
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
      =.  notes.notebook-state
        (~(put by notes.notebook-state) nid nt)
      =.  se-core  (se-update [%note nid [%created nt]])
      $(items t.items, se-core se-core)
    ::
        %folder
      =/  new-fid=@ud  +(next-id.state)
      =.  next-id.state  new-fid
      =/  nf=folder:n
        [new-fid nid-nb name.i.items `fid src.bowl now.bowl now.bowl src.bowl]
      =.  folders.notebook-state
        (~(put by folders.notebook-state) new-fid nf)
      =.  se-core  (se-update [%folder new-fid [%created nf]])
      $(items children.i.items, stack [[t.items fid] stack], fid new-fid, se-core se-core)
    ==
  ::
  ::  helpers
  ++  se-folder-children-ids
    |=  folder-id=@ud
    ^-  (list @ud)
    %+  murn  ~(tap by folders.notebook-state)
    |=  [fid=@ud fld=folder:n]
    ?~  parent-folder-id.fld  ~
    ?:  =(u.parent-folder-id.fld folder-id)
      `fid
    ~
  ::
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
  ++  se-note-ids-in-folder-set
    |=  fids=(set @ud)
    ^-  (set @ud)
    %-  silt
    %+  murn  ~(tap by notes.notebook-state)
    |=  [nid=@ud nt=note:n]
    ?:  (~(has in fids) folder-id.nt)
      `nid
    ~
  ::
  ++  se-notes-in-folder
    |=  folder-id=@ud
    ^-  (list note:n)
    %+  murn  ~(tap by notes.notebook-state)
    |=  [nid=@ud nt=note:n]
    ?:  =(folder-id.nt folder-id)
      `nt
    ~
  --
::
::  ====  no-core: subscriber/client core  ====
::
++  no-core
  |_  [=flag:n =net:n =notebook-state:n gone=_|]
  ++  no-core  .
  ++  emit  |=(=card no-core(cor cor(cards [card cards])))
  ++  give  |=(=gift:agent:gall (emit %give gift))
  ::
  ++  no-abed
    |=  f=flag:n
    ^+  no-core
    ?~  entry=(~(get by books.state) f)
      ~|(no-abed-not-found+f !!)
    =/  [=net:n =notebook-state:n]  u.entry
    no-core(flag f, net net, notebook-state notebook-state)
  ::
  ++  no-abet
    ^+  cor
    =.  books.state
      ?:  gone
        (~(del by books.state) flag)
      (~(put by books.state) flag [net notebook-state])
    cor
  ::
  ++  no-area
    `path`/notes/sub/(scot %p ship.flag)/[name.flag]
  ::
  ++  no-sub-wire
    `path`/notes/sub/(scot %p ship.flag)/[name.flag]
  ::
  ++  no-sub-path
    `path`/v0/notes/(scot %p ship.flag)/[name.flag]/updates
  ::
  ::  +no-action: convert local action to c-notes and send poke to host
  ++  no-action
    |=  act=action:n
    ^+  no-core
    ?>  ?=(%sub -.net)
    ?>  ?=(%notebook -.act)
    =/  cmd=command:n
      [%notebook flag.act (a-notebook-to-c-notebook a-notebook.act)]
    %-  emit
    :*  %pass
        no-sub-wire
        %agent
        [ship.flag %notes]
        %poke
        notes-command+!>(cmd)
    ==
  ::
  ++  no-start-watch
    ^+  no-core
    ?>  ?=(%sub -.net)
    %-  emit
    [%pass no-sub-wire %agent [ship.flag %notes] %watch no-sub-path]
  ::
  ++  no-leave
    ^+  no-core
    ?>  ?=(%sub -.net)
    =.  gone  &
    %-  emit
    [%pass no-sub-wire %agent [ship.flag %notes] %leave ~]
  ::
  ::  +no-agent: handle sign from host subscription
  ++  no-agent
    |=  =sign:agent:gall
    ^+  no-core
    ?>  ?=(%sub -.net)
    ?+  -.sign  no-core
        %fact
      =/  =response:n  !<(response:n q.cage.sign)
      (no-response response)
    ::
        %kick
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
      ?>  ?=(%sub -.net)
      =.  net  net(init |)
      no-core
    ==
  ::
  ::  +no-response: apply an update from the host to local state
  ++  no-response
    |=  =response:n
    ^+  no-core
    ?-  -.response
        %snapshot
      =.  notebook-state  notebook-state.response
      ?>  ?=(%sub -.net)
      =.  net  net(init &)
      =.  cards  [notebooks-changed-card cards]
      %-  give
      [%fact [/v0/notes/(scot %p ship.flag)/[name.flag]/stream]~ notes-response+!>(response)]
    ::
        %update
      =.  no-core  (no-apply-update flag.response update.response)
      %-  give
      [%fact [/v0/notes/(scot %p ship.flag)/[name.flag]/stream]~ notes-response+!>(response)]
    ==
  ::
  ::  +no-apply-update: apply a single u-notebook update to local state
  ++  no-apply-update
    |=  [=flag:n upd=update:n]
    ^+  no-core
    =/  u-nb=u-notebook:n  u-notebook.upd
    ?-  -.u-nb
        %created
      =.  notebook.notebook-state  notebook.u-nb
      no-core
    ::
        %updated
      =.  notebook.notebook-state  notebook.u-nb
      no-core
    ::
        %deleted
      no-core(gone &)
    ::
        %visibility
      ::  write visibility into local notebook-state
      =.  visibility.notebook-state  visibility.u-nb
      no-core
    ::
        %member-joined
      =.  members.notebook-state
        (~(put by members.notebook-state) who.u-nb role.u-nb)
      no-core
    ::
        %member-left
      =.  members.notebook-state
        (~(del by members.notebook-state) who.u-nb)
      no-core
    ::
        %invite-received
      no-core   :: handled via give-inbox-received on host; no local state
    ::
        %invite-removed
      no-core
    ::
        %folder
      (no-apply-folder-update id.u-nb u-folder.u-nb)
    ::
        %note
      (no-apply-note-update id.u-nb u-note.u-nb)
    ==
  ::
  ++  no-apply-folder-update
    |=  [fid=@ud upd=u-folder:n]
    ^+  no-core
    ?-  -.upd
        %created
      =.  folders.notebook-state
        (~(put by folders.notebook-state) fid folder.upd)
      no-core
        %updated
      =.  folders.notebook-state
        (~(put by folders.notebook-state) fid folder.upd)
      no-core
        %deleted
      =.  folders.notebook-state
        (~(del by folders.notebook-state) fid)
      no-core
    ==
  ::
  ++  no-apply-note-update
    |=  [nid=@ud upd=u-note:n]
    ^+  no-core
    ?-  -.upd
        %created
      =.  notes.notebook-state
        (~(put by notes.notebook-state) nid note.upd)
      no-core
        %updated
      =.  notes.notebook-state
        (~(put by notes.notebook-state) nid note.upd)
      no-core
        %deleted
      =.  notes.notebook-state
        (~(del by notes.notebook-state) nid)
      no-core
        %published
      no-core   :: host-side only; subscriber doesn't track published state
        %unpublished
      no-core
        %history-archived
      ::  append archived revision to local per-notebook history cache
      =/  existing=(list note-revision:n)
        (fall (~(get by history.notebook-state) nid) ~)
      =.  history.notebook-state
        (~(put by history.notebook-state) nid [note-revision.upd existing])
      no-core
    ==
  ::
  ::  +no-peek: handle per-notebook scry requests
  ::  kind: the path segment after /v0/ (e.g. %notebook, %notes, %note, etc.)
  ::  rest: the remainder of the pole after kind/ship/name (typed as *)
  ++  no-peek
    |=  [kind=@ rest=*]
    ^-  (unit (unit cage))
    ?>  ?=(^ (~(get by members.notebook-state) src.bowl))
    ?+  kind  ~
        %notebook
      =-  ``json+!>((pairs:enjs:format -))
      :~  ['host' s+(scot %p ship.flag)]
          ['flagName' s+name.flag]
          ['notebook' (notebook:enjs:notes-json notebook.notebook-state)]
      ==
    ::
        %folders
      =/  flds=(list json)
        %+  turn  ~(val by folders.notebook-state)
        folder:enjs:notes-json
      ``json+!>([%a flds])
    ::
        %notes
      =/  nts=(list json)
        %+  turn  ~(val by notes.notebook-state)
        note:enjs:notes-json
      ``json+!>([%a nts])
    ::
        %note
      =/  nid=@ud  (slav %ud ;;(@ -.rest))
      ?~  nt=(~(get by notes.notebook-state) nid)
        ``json+!>(~)
      ``json+!>((note:enjs:notes-json u.nt))
    ::
        %note-history
      =/  nid=@ud  (slav %ud ;;(@ -.rest))
      =/  revs=(list note-revision:n)
        (fall (~(get by history.notebook-state) nid) ~)
      =/  items=(list json)
        %+  turn  revs
        note-revision:enjs:notes-json
      ``json+!>([%a items])
    ::
        %folder
      =/  fid=@ud  (slav %ud ;;(@ -.rest))
      ?~  fld=(~(get by folders.notebook-state) fid)
        ``json+!>(~)
      ``json+!>((folder:enjs:notes-json u.fld))
    ::
        %members
      =/  mlist=(list json)
        %+  turn  ~(tap by members.notebook-state)
        |=  [who=ship r=role:n]
        %-  pairs:enjs:format
        :~  ['ship' s+(scot %p who)]
            ['role' s+(scot %tas r)]
        ==
      ``json+!>([%a mlist])
    ==
  ::
  ::  +no-watch: handle local UI stream subscription for this notebook
  ++  no-watch
    ^+  no-core
    ?>  ?=(^ (~(get by members.notebook-state) src.bowl))
    %-  give
    :+  %fact
      [`path`/v0/notes/(scot %p ship.flag)/[name.flag]/stream]~
    notes-response+!>(`response:n`[%snapshot flag visibility.notebook-state notebook-state])
  --
--
