::  notes: shared notebook Gall agent (dual-mode host/subscriber)
::
/-  notes
/+  default-agent, dbug, verb, notes-json
/=  index        /lib/notes-ui
/=  share-page   /lib/notes-share
::
|%
+$  card  card:agent:gall
+$  current-state  state-10:notes
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
++  dummy  'state-10-flag-tas-slug-v1'
++  abet  [(flop cards) state]
++  cor   .
++  emit  |=(=card cor(cards [card cards]))
++  emil  |=(caz=(list card) cor(cards (welp (flop caz) cards)))
++  give  |=(=gift:agent:gall (emit %give gift))
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
++  init
  ^+  cor
  %-  emit
  [%pass /eyre/notes %arvo %e %connect [~ /notes] %notes]
::
::  +manifest: web app manifest served at /notes/manifest.json. The
::  start_url and scope are anchored at /notes/ so the install prompt
::  and the service worker only see this app's URL space.
++  manifest
  ^-  @t
  '''
  {
    "name": "Notes",
    "short_name": "Notes",
    "description": "Collaborative markdown notebooks",
    "start_url": "/notes/",
    "scope": "/notes/",
    "display": "standalone",
    "background_color": "#0f0f0f",
    "theme_color": "#7c6af7",
    "icons": [
      { "src": "/notes/icon.svg", "sizes": "192x192", "type": "image/svg+xml", "purpose": "any" },
      { "src": "/notes/icon.svg", "sizes": "512x512", "type": "image/svg+xml", "purpose": "any" },
      { "src": "/notes/icon.svg", "sizes": "any", "type": "image/svg+xml", "purpose": "maskable" }
    ]
  }
  '''
::
::  +service-worker: pass-through SW that satisfies the install criteria
::  on Chrome/Android without taking responsibility for offline caching
::  yet. Real offline support (app-shell + IndexedDB) is deferred.
++  service-worker
  ^-  @t
  '''
  self.addEventListener("install", (e) => self.skipWaiting());
  self.addEventListener("activate", (e) => self.clients.claim());
  self.addEventListener("fetch", (e) => {
    // No caching: defer offline support to a later pass. We still need
    // a fetch handler for the install prompt to be eligible.
  });
  '''
::
::  +favicon-svg: tight Paper-original design used for the browser tab.
::  Inset 96/66 (19%/13%) — looks great at 16-32px favicon size where
::  more padding would just shrink the recognizable shape.
++  favicon-svg
  ^-  @t
  '''
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
    <rect width="512" height="512" rx="112" fill="#7C6AF7"/>
    <rect x="96" y="66" width="320" height="380" rx="32" fill="none" stroke="#FFFFFF" stroke-width="18"/>
    <line x1="186" y1="66" x2="186" y2="446" stroke="#FFFFFF" stroke-width="18" stroke-linecap="round"/>
  </svg>
  '''
::
::  +icon-svg: padded variant used by the manifest (PWA install / dock /
::  home-screen icon). Same Paper proportions, scaled to ~70% of the
::  canvas with the stroke trimmed proportionally so the design reads
::  consistently when shrunk. macOS/iOS app icons want roughly 18-24%
::  padding around content.
++  icon-svg
  ^-  @t
  '''
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
    <rect width="512" height="512" rx="112" fill="#7C6AF7"/>
    <rect x="144" y="123" width="224" height="266" rx="22" fill="none" stroke="#FFFFFF" stroke-width="16"/>
    <line x1="207" y1="123" x2="207" y2="389" stroke="#FFFFFF" stroke-width="16" stroke-linecap="round"/>
  </svg>
  '''
::
::  +load: migrate old state to current state-10
::  Migration cascade: 0→1→2→3→4→5→6→7→8→9→10.
::  state-9 → state-10: re-slug all flag names from @t cord to @tas term.
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
  ::  state-10: current format
  ?:  =(tag %10)
    =/  s=current-state  !<(current-state old)
    =.  state  s
    cor
  ::  state-9 → state-10: re-slug all flag names (@t → @tas).
  ::  Build a translation map (flag-v9 → flag) using each notebook's title+id.
  ::  Note: subscriber notebooks (ship != our.bowl) are also re-slugged using
  ::  the host's title; cross-ship subscriptions will need to be re-established
  ::  since the host's flag slug is computed independently.
  ?:  =(tag %9)
    =/  s=state-9:notes  !<(state-9:notes old)
    ::  build translation map: old flag-v9 → new flag
    =/  xlat=(map flag-v9:notes flag:notes)
      %-  malt
      %+  turn  ~(tap by books.s)
      |=  [f=flag-v9:notes [=net:notes =notebook-state:notes]]
      =/  nid=@ud  id.notebook.notebook-state
      =/  new-name=@tas  (slugify title.notebook.notebook-state nid)
      [f [ship.f new-name]]
    ::  re-key books
    =/  new-books=(map flag:notes [=net:notes =notebook-state:notes])
      %-  malt
      %+  turn  ~(tap by books.s)
      |=  [f=flag-v9:notes entry=[=net:notes =notebook-state:notes]]
      =/  nf=flag:notes  (~(got by xlat) f)
      [nf entry]
    ::  re-key published
    =/  new-pub=(map [=flag:notes note-id=@ud] @t)
      %-  malt
      %+  turn  ~(tap by published.s)
      |=  [[f=flag-v9:notes nid=@ud] html=@t]
      =/  nf=flag:notes  (fall (~(get by xlat) f) [ship.f `@tas`name.f])
      [[nf nid] html]
    ::  re-key invites
    =/  new-invites=(map flag:notes invite-info:notes)
      %-  malt
      %+  turn  ~(tap by invites.s)
      |=  [f=flag-v9:notes info=invite-info:notes]
      =/  nf=flag:notes  (fall (~(get by xlat) f) [ship.f `@tas`name.f])
      [nf info]
    =.  state  [%10 new-books next-id.s new-pub new-invites]
    cor
  ::  state-8 → state-9: move visibility + history into per-notebook-state;
  ::  rename notebook-members → members.
  ?:  =(tag %8)
    =/  s=state-8:notes  !<(state-8:notes old)
    =/  new-books=(map flag-v9:notes [=net:notes =notebook-state:notes])
      %-  ~(urn by books.s)
      |=  [f=flag-v9:notes [=net:notes old-nbs=notebook-state-v8:notes]]
      ::  filter history entries for this notebook flag; key by note-id only
      =/  nb-hist=(map @ud (list note-revision:notes))
        %-  malt
        %+  murn  ~(tap by history.s)
        |=  [[kf=flag-v9:notes nid=@ud] v=(list note-revision:notes)]
        ?.  =(kf f)  ~
        `[nid v]
      =/  new-nbs=notebook-state:notes
        :*  notebook.old-nbs
            notebook-members.old-nbs
            (fall (~(get by visibilities.s) f) %private)
            folders.old-nbs
            notes.old-nbs
            nb-hist
        ==
      [net new-nbs]
    =/  s9=state-9:notes
      [%9 new-books next-id.s published.s invites.s]
    (load !>(s9))
  ::  state-7 → state-8: backfill updated-by; truncate pub logs.
  ?:  =(tag %7)
    =/  s=state-7:notes  !<(state-7:notes old)
    =/  new-books=(map flag-v9:notes [=net:notes =notebook-state-v8:notes])
      %-  ~(run by books.s)
      |=  [net=net-v0:notes old-nbs=notebook-state-v0:notes]
      =/  new-nb=notebook:notes
        :*  id.notebook.old-nbs  title.notebook.old-nbs
            created-by.notebook.old-nbs  created-at.notebook.old-nbs
            updated-at.notebook.old-nbs  created-by.notebook.old-nbs
        ==
      =/  new-folders=(map @ud folder:notes)
        %-  ~(run by folders.old-nbs)
        |=  fld=folder-v0:notes
        :*  id.fld  notebook-id.fld  name.fld  parent-folder-id.fld
            created-by.fld  created-at.fld  updated-at.fld  created-by.fld
        ==
      =/  new-net=net:notes
        ?-  -.net
          %pub  [%pub *log:notes]
          %sub  [%sub time.net init.net]
        ==
      [new-net [new-nb notebook-members.old-nbs new-folders notes.old-nbs]]
    =/  s8=state-8:notes
      [%8 new-books next-id.s published.s visibilities.s invites.s history.s]
    =/  s8-vase=vase  !>(s8)
    (load s8-vase)
  ::  state-6 → state-8: add empty history, backfill updated-by
  ?:  =(tag %6)
    =/  s=state-6:notes  !<(state-6:notes old)
    =/  new-books=(map flag-v9:notes [=net:notes =notebook-state-v8:notes])
      %-  ~(run by books.s)
      |=  [net=net-v0:notes old-nbs=notebook-state-v0:notes]
      =/  new-nb=notebook:notes
        :*  id.notebook.old-nbs  title.notebook.old-nbs
            created-by.notebook.old-nbs  created-at.notebook.old-nbs
            updated-at.notebook.old-nbs  created-by.notebook.old-nbs
        ==
      =/  new-folders=(map @ud folder:notes)
        %-  ~(run by folders.old-nbs)
        |=  fld=folder-v0:notes
        :*  id.fld  notebook-id.fld  name.fld  parent-folder-id.fld
            created-by.fld  created-at.fld  updated-at.fld  created-by.fld
        ==
      =/  new-net=net:notes
        ?-  -.net
          %pub  [%pub *log:notes]
          %sub  [%sub time.net init.net]
        ==
      [new-net [new-nb notebook-members.old-nbs new-folders notes.old-nbs]]
    =/  s8=state-8:notes
      [%8 new-books next-id.s published.s visibilities.s invites.s ~]
    (load !>(s8))
  ::  state-5 → state-8: drop old-shape invites, backfill updated-by
  ?:  =(tag %5)
    =/  s=state-5:notes  !<(state-5:notes old)
    =/  new-books=(map flag-v9:notes [=net:notes =notebook-state-v8:notes])
      %-  ~(run by books.s)
      |=  [net=net-v0:notes old-nbs=notebook-state-v0:notes]
      =/  new-nb=notebook:notes
        :*  id.notebook.old-nbs  title.notebook.old-nbs
            created-by.notebook.old-nbs  created-at.notebook.old-nbs
            updated-at.notebook.old-nbs  created-by.notebook.old-nbs
        ==
      =/  new-folders=(map @ud folder:notes)
        %-  ~(run by folders.old-nbs)
        |=  fld=folder-v0:notes
        :*  id.fld  notebook-id.fld  name.fld  parent-folder-id.fld
            created-by.fld  created-at.fld  updated-at.fld  created-by.fld
        ==
      [[%pub *log:notes] [new-nb notebook-members.old-nbs new-folders notes.old-nbs]]
    =/  s8=state-8:notes
      [%8 new-books next-id.s published.s visibilities.s ~ ~]
    (load !>(s8))
  ::  state-4 → state-8: add empty invites + history, backfill updated-by
  ?:  =(tag %4)
    =/  s=state-4:notes  !<(state-4:notes old)
    =/  new-books=(map flag-v9:notes [=net:notes =notebook-state-v8:notes])
      %-  ~(run by books.s)
      |=  [net=net-v0:notes old-nbs=notebook-state-v0:notes]
      =/  new-nb=notebook:notes
        :*  id.notebook.old-nbs  title.notebook.old-nbs
            created-by.notebook.old-nbs  created-at.notebook.old-nbs
            updated-at.notebook.old-nbs  created-by.notebook.old-nbs
        ==
      =/  new-folders=(map @ud folder:notes)
        %-  ~(run by folders.old-nbs)
        |=  fld=folder-v0:notes
        :*  id.fld  notebook-id.fld  name.fld  parent-folder-id.fld
            created-by.fld  created-at.fld  updated-at.fld  created-by.fld
        ==
      [[%pub *log:notes] [new-nb notebook-members.old-nbs new-folders notes.old-nbs]]
    =/  s8=state-8:notes
      [%8 new-books next-id.s published.s visibilities.s ~ ~]
    (load !>(s8))
  ::  state-3 → state-8: add empty visibilities + invites + history, backfill updated-by
  ?:  =(tag %3)
    =/  s=state-3:notes  !<(state-3:notes old)
    =/  new-books=(map flag-v9:notes [=net:notes =notebook-state-v8:notes])
      %-  ~(run by books.s)
      |=  [net=net-v0:notes old-nbs=notebook-state-v0:notes]
      =/  new-nb=notebook:notes
        :*  id.notebook.old-nbs  title.notebook.old-nbs
            created-by.notebook.old-nbs  created-at.notebook.old-nbs
            updated-at.notebook.old-nbs  created-by.notebook.old-nbs
        ==
      =/  new-folders=(map @ud folder:notes)
        %-  ~(run by folders.old-nbs)
        |=  fld=folder-v0:notes
        :*  id.fld  notebook-id.fld  name.fld  parent-folder-id.fld
            created-by.fld  created-at.fld  updated-at.fld  created-by.fld
        ==
      [[%pub *log:notes] [new-nb notebook-members.old-nbs new-folders notes.old-nbs]]
    =/  s8=state-8:notes
      [%8 new-books next-id.s published.s ~ ~ ~]
    (load !>(s8))
  ::  state-2 → state-8: drop published, backfill
  ?:  =(tag %2)
    =/  s=state-2:notes  !<(state-2:notes old)
    =/  new-books=(map flag-v9:notes [=net:notes =notebook-state-v8:notes])
      %-  ~(run by books.s)
      |=  [net=net-v0:notes old-nbs=notebook-state-v0:notes]
      =/  new-nb=notebook:notes
        :*  id.notebook.old-nbs  title.notebook.old-nbs
            created-by.notebook.old-nbs  created-at.notebook.old-nbs
            updated-at.notebook.old-nbs  created-by.notebook.old-nbs
        ==
      =/  new-folders=(map @ud folder:notes)
        %-  ~(run by folders.old-nbs)
        |=  fld=folder-v0:notes
        :*  id.fld  notebook-id.fld  name.fld  parent-folder-id.fld
            created-by.fld  created-at.fld  updated-at.fld  created-by.fld
        ==
      [[%pub *log:notes] [new-nb notebook-members.old-nbs new-folders notes.old-nbs]]
    =/  s8=state-8:notes
      [%8 new-books next-id.s ~ ~ ~ ~]
    (load !>(s8))
  ::  state-1 → state-8: backfill
  ?:  =(tag %1)
    =/  s=state-1:notes  !<(state-1:notes old)
    =/  new-books=(map flag-v9:notes [=net:notes =notebook-state-v8:notes])
      %-  ~(run by books.s)
      |=  [net=net-v0:notes old-nbs=notebook-state-v0:notes]
      =/  new-nb=notebook:notes
        :*  id.notebook.old-nbs  title.notebook.old-nbs
            created-by.notebook.old-nbs  created-at.notebook.old-nbs
            updated-at.notebook.old-nbs  created-by.notebook.old-nbs
        ==
      =/  new-folders=(map @ud folder:notes)
        %-  ~(run by folders.old-nbs)
        |=  fld=folder-v0:notes
        :*  id.fld  notebook-id.fld  name.fld  parent-folder-id.fld
            created-by.fld  created-at.fld  updated-at.fld  created-by.fld
        ==
      [[%pub *log:notes] [new-nb notebook-members.old-nbs new-folders notes.old-nbs]]
    =/  s8=state-8:notes
      [%8 new-books next-id.s ~ ~ ~ ~]
    (load !>(s8))
  ::  state-0 or unknown: start fresh
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
    ::  drop any query string for path-only matching
    =/  url-path=tape  (strip-query url-tape)
    ::  PWA-related static assets: manifest, service worker, icon.
    ::  Each returns [body content-type] or ~. Served scoped under
    ::  /notes/ so the SW can control the app's URL space.
    =/  asset=(unit [body=@t ct=@t])
      ?:  =("/notes/manifest.json" url-path)
        `[manifest 'application/manifest+json']
      ?:  =("/notes/sw.js" url-path)
        ::  Service-Worker-Allowed isn't required since the SW lives at
        ::  /notes/sw.js and only needs to control /notes/, but text/javascript
        ::  is required by some browsers for SW registration to succeed.
        `[service-worker 'text/javascript']
      ?:  =("/notes/icon.svg" url-path)
        `[icon-svg 'image/svg+xml']
      ?:  =("/notes/favicon.svg" url-path)
        `[favicon-svg 'image/svg+xml']
      ~
    ::  check if this is a published note request: /notes/pub/~ship/name/{note-id}
    =/  pub-html=(unit @t)
      ?.  =("/notes/pub/" (scag 11 url-tape))  ~
      =/  rest=tape  (slag 11 url-tape)
      ::  drop any query string
      =/  path-only=tape  (strip-query rest)
      ::  parse /~ship/name/note-id via stab
      =/  pax=path  (stab (crip (weld "/" path-only)))
      ?.  ?=([@ @ @ ~] pax)  ~
      ?~  ship-u=(slaw %p i.pax)  ~
      ?~  nid-u=(slaw %ud i.t.t.pax)  ~
      ?:  =(0 u.nid-u)  ~
      =/  =flag:notes  [u.ship-u `@tas`i.t.pax]
      (~(get by published.state) [flag u.nid-u])
    ::  check if this is a share-redirect request: /notes/share/~ship/name
    =/  share-html=(unit @t)
      ?.  =("/notes/share/" (scag 13 url-tape))  ~
      =/  rest=tape  (slag 13 url-tape)
      =/  path-only=tape  (strip-query rest)
      =/  pax=path  (stab (crip (weld "/" path-only)))
      ?.  ?=([@ @ ~] pax)  ~
      ?~  (slaw %p i.pax)  ~
      `share-page
    ::  serve asset, published note, share page, or the UI (in that order)
    =/  body=@t
      ?^  asset      body.u.asset
      ?^  pub-html   u.pub-html
      ?^  share-html  u.share-html
      index
    =/  ct=@t
      ?^  asset  ct.u.asset
      'text/html'
    =/  data=octs  [(met 3 body) body]
    =/  headers=(list [key=@t value=@t])
      :~  ['content-type' ct]
      ==
    =/  =response-header:http  [200 headers]
    %-  emil
    :~  [%give %fact [/http-response/[eyre-id.req]]~ %http-response-header !>(response-header)]
        [%give %fact [/http-response/[eyre-id.req]]~ %http-response-data !>(`data)]
        [%give %kick [/http-response/[eyre-id.req]]~ ~]
    ==
  ::
      %notes-action
    ::  Actions are local UI requests — they originate from our own ship.
    ::  Cross-ship messages (host → invitee notify-invite, subscriber →
    ::  host commands) flow via %notes-command instead.
    ?>  =(our.bowl src.bowl)
    =+  !<(act=action:notes vase)
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
    =/  =flag:notes  flag.act
    =/  nb-act=a-notebook:notes  a-notebook.act
    ::  %invite: owner sends invite to a ship — handled locally
    ?:  ?=(%invite -.nb-act)
      (handle-send-invite flag who.nb-act)
    ::  %note [%publish]/[%unpublish]: local-only, not forwarded to remote hosts
    ?:  ?=(%note -.nb-act)
      =/  nid=@ud  id.nb-act
      =/  n-act=a-note:notes  a-note.nb-act
      ?:  ?=(%publish -.n-act)
        =.  published.state  (~(put by published.state) [flag nid] html.n-act)
        cor
      ?:  ?=(%unpublish -.n-act)
        =.  published.state  (~(del by published.state) [flag nid])
        cor
      ::  all other note actions: route to se/no core
      =/  entry=[=net:notes =notebook-state:notes]
        (~(got by books.state) flag)
      ?:  ?=(%pub -.net.entry)
        se-abet:(se-poke:(se-abed:se-core flag) [flag (a-notebook-to-c-notebook nb-act)])
      no-abet:(no-action:(no-abed:no-core flag) act)
    ::  all other notebook actions: route to se/no core
    =/  entry=[=net:notes =notebook-state:notes]
      (~(got by books.state) flag)
    ?:  ?=(%pub -.net.entry)
      se-abet:(se-poke:(se-abed:se-core flag) [flag (a-notebook-to-c-notebook nb-act)])
    no-abet:(no-action:(no-abed:no-core flag) act)
  ::
      %notes-command
    =+  !<(cmd=command:notes vase)
    ?-    -.cmd
        %notify-invite
      ::  Cross-ship invite delivery — src.bowl validation lives in
      ::  handle-notify-invite (must equal ship.flag, the inviting host).
      (handle-notify-invite flag.cmd title.cmd src.bowl)
    ::
        %notebook
      =/  =flag:notes  flag.cmd
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
::  +a-notebook-to-c-notebook: convert a-notebook to c-notebook (same shape except %restore)
::  %restore is rewritten to %note [id %update] with the archived body
++  a-notebook-to-c-notebook
  |=  nb-act=a-notebook:notes
  ^-  c-notebook:notes
  ::  a-notebook and c-notebook have identical shapes (c-notebook adds
  ::  %member-join/%member-leave which only arrive via %notes-command, never
  ::  via %notes-action from the client). Direct cast works for all a-notebook arms.
  ;;(c-notebook:notes nb-act)
::
::  +join-remote: initiate joining a notebook on a remote ship
++  join-remote
  |=  =flag:notes
  ^+  cor
  ?<  =(our.bowl ship.flag)
  ?<  (~(has by books.state) flag)
  =/  placeholder-net=net:notes  [%sub *@da |]
  =/  placeholder-nb=notebook:notes
    [0 '' ship.flag *@da *@da ship.flag]
  =/  placeholder-nb-state=notebook-state:notes
    [placeholder-nb ~ %private ~ ~ ~]
  =.  books.state
    (~(put by books.state) flag [placeholder-net placeholder-nb-state])
  ::  send %member-join command to host (wrapped in c-notes %notebook arm)
  %-  emit
  :+  %pass
    /notes/join/(scot %p ship.flag)/[name.flag]
  [%agent [ship.flag %notes] %poke notes-command+!>(`command:notes`[%notebook flag [%member-join ~]])]
::
::  +leave-remote: leave a notebook on a remote ship
++  leave-remote
  |=  =flag:notes
  ^+  cor
  ?>  (~(has by books.state) flag)
  no-abet:no-leave:(no-abed:no-core flag)
::
::  +handle-send-invite: owner-only, fired locally. Pre-add the target ship
::  to the notebook's member list and notify their %notes agent.
++  handle-send-invite
  |=  [=flag:notes who=ship]
  ^+  cor
  ?>  =(ship.flag our.bowl)
  =/  entry=[=net:notes =notebook-state:notes]
    (~(got by books.state) flag)
  =/  title=@t  title.notebook.notebook-state.entry
  ::  pre-add via se-core (also enforces ownership)
  =.  cor
    =/  cmd=c-cmd:notes  [flag [%invite who]]
    se-abet:(se-poke:(se-abed:se-core flag) cmd)
  ::  Poke the invitee's notes agent with %notify-invite as a c-notes
  ::  command — actions are local-only (src must equal our), so cross-
  ::  ship invite delivery flows through the command surface. The arm
  ::  carries the notebook title so the inbox can render it pre-join.
  %-  emit
  :+  %pass
    /notes/invite/(scot %p who)/(scot %p ship.flag)/[name.flag]
  [%agent [who %notes] %poke notes-command+!>(`command:notes`[%notify-invite flag title])]
::
::  +handle-notify-invite: called when a remote host pokes us with
::  [%notify-invite flag title]. The sender must be the notebook host.
++  handle-notify-invite
  |=  [=flag:notes title=@t from=ship]
  ^+  cor
  ?<  =(from our.bowl)
  ?>  =(from ship.flag)
  ?:  (~(has by books.state) flag)  cor
  ?:  (~(has by invites.state) flag)  cor
  =/  info=invite-info:notes  [from now.bowl title]
  =.  invites.state  (~(put by invites.state) flag info)
  (give-inbox-received flag from now.bowl title)
::
::  +handle-accept-invite: user accepted a pending invite
++  handle-accept-invite
  |=  =flag:notes
  ^+  cor
  ?>  =(src.bowl our.bowl)
  =.  invites.state  (~(del by invites.state) flag)
  =.  cor  (give-inbox-removed flag)
  ?:  (~(has by books.state) flag)  cor
  (join-remote flag)
::
::  +handle-decline-invite: user declined a pending invite
++  handle-decline-invite
  |=  =flag:notes
  ^+  cor
  ?>  =(src.bowl our.bowl)
  ?.  (~(has by invites.state) flag)  cor
  =.  invites.state  (~(del by invites.state) flag)
  (give-inbox-removed flag)
::
::  +give-inbox-received: emit an invite-received event on /v0/inbox/stream
++  give-inbox-received
  |=  [=flag:notes from=ship sent-at=@da title=@t]
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
  |=  =flag:notes
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
::  +notebooks-changed-card: a fact telling subscribed UIs to re-scry notebooks
++  notebooks-changed-card
  ^-  card
  =/  evt=json
    (pairs:enjs:format ~[['type' s+'notebooks-changed']])
  [%give %fact [/v0/inbox/stream]~ json+!>((pairs:enjs:format ~[['type' s+'update'] ['update' evt]]))]
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
    =/  =flag:notes  [(slav %p ship.pole) `@tas`name.pole]
    ?>  =(our.bowl ship.flag)
    ?~  entry=(get-book flag)  ~|(notebook-not-found+flag !!)
    ?>  ?=(%pub -.net.u.entry)
    ?>  (se-can-view:(se-abed:se-core flag) src.bowl)
    ::  send initial snapshot (with visibility so subscriber can seed it)
    se-abet:(se-watch-sub:(se-abed:se-core flag) src.bowl)
  ::
      [%v0 %notes ship=@ name=@ %stream ~]
    ::  local UI subscription
    =/  =flag:notes  [(slav %p ship.pole) `@tas`name.pole]
    ?~  entry=(get-book flag)  ~|(notebook-not-found+flag !!)
    ?>  (can-view-flag flag src.bowl)
    ::  send initial snapshot carrying visibility from notebook-state
    %-  give
    :+  %fact  [`path`pole]~
    notes-response+!>(`response:notes`[%snapshot flag visibility.notebook-state.u.entry notebook-state.u.entry])
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
          ['visibility' s+(scot %tas visibility.notebook-state)]
      ==
    ``json+!>([%a nbs])
    ::  /x/v0/notebook/<ship>/<name>
      [%x %v0 %notebook ship=@ name=@ ~]
    =/  =flag:notes  [(slav %p ship.pole) `@tas`name.pole]
    ?~  entry=(get-book flag)  ``json+!>(~)
    ?>  (can-view-flag flag src.bowl)
    =-  ``json+!>((pairs:enjs:format -))
    :~  ['host' s+(scot %p ship.flag)]
        ['flagName' s+name.flag]
        ['notebook' (notebook:enjs:notes-json notebook.notebook-state.u.entry)]
    ==
    ::  /x/v0/folders/<ship>/<name>
      [%x %v0 %folders ship=@ name=@ ~]
    =/  =flag:notes  [(slav %p ship.pole) `@tas`name.pole]
    ?~  entry=(get-book flag)  ``json+!>(~)
    ?>  (can-view-flag flag src.bowl)
    =/  flds=(list json)
      %+  turn  ~(val by folders.notebook-state.u.entry)
      folder:enjs:notes-json
    ``json+!>([%a flds])
    ::  /x/v0/notes/<ship>/<name>
      [%x %v0 %notes ship=@ name=@ ~]
    =/  =flag:notes  [(slav %p ship.pole) `@tas`name.pole]
    ?~  entry=(get-book flag)  ``json+!>(~)
    ?>  (can-view-flag flag src.bowl)
    =/  nts=(list json)
      %+  turn  ~(val by notes.notebook-state.u.entry)
      note:enjs:notes-json
    ``json+!>([%a nts])
    ::  /x/v0/note/<ship>/<name>/<id> — single note by ID
      [%x %v0 %note ship=@ name=@ id=@ ~]
    =/  =flag:notes  [(slav %p ship.pole) `@tas`name.pole]
    ?~  entry=(get-book flag)  ``json+!>(~)
    ?>  (can-view-flag flag src.bowl)
    =/  nid=@ud  (slav %ud id.pole)
    ?~  nt=(~(get by notes.notebook-state.u.entry) nid)
      ``json+!>(~)
    ``json+!>((note:enjs:notes-json u.nt))
    ::  /x/v0/note-history/<ship>/<name>/<id> — revision history for a note
      [%x %v0 %note-history ship=@ name=@ id=@ ~]
    =/  =flag:notes  [(slav %p ship.pole) `@tas`name.pole]
    ?~  entry=(get-book flag)  ``json+!>(~)
    ?>  (can-view-flag flag src.bowl)
    =/  nid=@ud  (slav %ud id.pole)
    =/  revs=(list note-revision:notes)
      (fall (~(get by history.notebook-state.u.entry) nid) ~)
    =/  items=(list json)
      %+  turn  revs
      note-revision:enjs:notes-json
    ``json+!>([%a items])
    ::  /x/v0/folder/<ship>/<name>/<id> — single folder by ID
      [%x %v0 %folder ship=@ name=@ id=@ ~]
    =/  =flag:notes  [(slav %p ship.pole) `@tas`name.pole]
    ?~  entry=(get-book flag)  ``json+!>(~)
    ?>  (can-view-flag flag src.bowl)
    =/  fid=@ud  (slav %ud id.pole)
    ?~  fld=(~(get by folders.notebook-state.u.entry) fid)
      ``json+!>(~)
    ``json+!>((folder:enjs:notes-json u.fld))
    ::  /x/v0/members/<ship>/<name>
      [%x %v0 %members ship=@ name=@ ~]
    =/  =flag:notes  [(slav %p ship.pole) `@tas`name.pole]
    ?~  entry=(get-book flag)  ``json+!>(~)
    ?>  (can-view-flag flag src.bowl)
    =/  mlist=(list json)
      %+  turn  ~(tap by members.notebook-state.u.entry)
      |=  [who=ship r=role:notes]
      %-  pairs:enjs:format
      :~  ['ship' s+(scot %p who)]
          ['role' s+(scot %tas r)]
      ==
    ``json+!>([%a mlist])
    ::  /x/v0/published — list of {host, flagName, noteId} for each published note
      [%x %v0 %published ~]
    =/  items=(list json)
      %+  turn  ~(tap in ~(key by published.state))
      |=  [=flag:notes note-id=@ud]
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
      |=  [=flag:notes info=invite-info:notes]
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
  ==
::
++  agent
  |=  [=(pole knot) =sign:agent:gall]
  ^+  cor
  ?+  pole  ~|(bad-agent-wire+pole !!)
      [%notes %sub ship=@ name=@ ~]
    =/  =flag:notes
      [(slav %p ship.pole) `@tas`name.pole]
    ?.  (~(has by books.state) flag)
      cor
    no-abet:(no-agent:(no-abed:no-core flag) sign)
  ::
      [%notes %join ship=@ name=@ ~]
    =/  =flag:notes
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
::  +can-view-flag: check if ship can view a notebook by flag
++  can-view-flag
  |=  [=flag:notes who=ship]
  ^-  ?
  ?~  entry=(get-book flag)  |
  =/  mbrs=members:notes
    members.notebook-state.u.entry
  ?~  (~(get by mbrs) who)  |
  &
::
::  +get-book: lookup a notebook entry by flag
++  get-book
  |=  =flag:notes
  ^-  (unit [=net:notes =notebook-state:notes])
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
::  +find-flag-by-nid: find the flag for a notebook by numeric notebook id
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
::  ====  se-core: server/host core  ====
::
++  se-core
  |_  [=flag:notes =log:notes =notebook-state:notes gone=_|]
  ++  se-core  .
  ++  emit  |=(=card se-core(cor cor(cards [card cards])))
  ++  give  |=(=gift:agent:gall (emit %give gift))
  ::
  ::  +se-init: initialize for a brand-new notebook
  ++  se-init
    |=  act=action:notes
    ^+  se-core
    ?>  ?=(%create-notebook -.act)
    =/  nid=@ud  +(next-id.state)
    =/  =flag:notes  [our.bowl (slugify title.act nid)]
    se-core(flag flag)
  ::
  ::  +se-abed: load from state for a given flag
  ++  se-abed
    |=  f=flag:notes
    ^+  se-core
    ?>  =(ship.f our.bowl)
    ?~  entry=(~(get by books.state) f)
      ~|(se-abed-not-found+f !!)
    =/  [=net:notes =notebook-state:notes]  u.entry
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
    |=  upd=u-notebook:notes
    ^+  se-core
    =/  ts=@da
      |-
      ?~  existing=(get:log-on:notes log now.bowl)  now.bowl
      $(now.bowl `@da`(add now.bowl ^~((div ~s1 (bex 16)))))
    =.  log  (put:log-on:notes log [ts upd])
    %-  give
    :+  %fact  ~[se-sub-path (weld se-area /stream)]
    notes-response+!>(`response:notes`[%update flag [ts upd]])
  ::
  ::  +se-watch-sub: send initial snapshot to a new subscriber (with visibility)
  ++  se-watch-sub
    |=  who=ship
    ^+  se-core
    %-  give
    [%fact ~ notes-response+!>(`response:notes`[%snapshot flag visibility.notebook-state notebook-state])]
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
    =/  r=(unit role:notes)
      (~(get by members.notebook-state) who)
    ?~  r  |
    ?|  =(u.r %owner)
        =(u.r %editor)
    ==
  ::
  ++  se-is-owner
    |=  who=ship
    ^-  ?
    =/  r=(unit role:notes)
      (~(get by members.notebook-state) who)
    ?~  r  |
    =(u.r %owner)
  ::
  ++  se-visibility
    ^-  visibility:notes
    visibility.notebook-state
  ::
  ::  +se-create-notebook: handle %create-notebook action
  ::  nid is +(next-id.state) — same value se-init used to build the flag slug;
  ::  state has not been modified between se-init and this call.
  ++  se-create-notebook
    |=  act=action:notes
    ?>  ?=(%create-notebook -.act)
    ^+  se-core
    =/  nid=@ud  +(next-id.state)
    =/  rfid=@ud  +(nid)
    =/  nb=notebook:notes
      [nid title.act our.bowl now.bowl now.bowl our.bowl]
    =/  nb-state=notebook-state:notes
      :*  nb
          (~(put by *members:notes) our.bowl %owner)
          %private
          (~(put by *(map @ud folder:notes)) rfid [rfid nid '/' ~ our.bowl now.bowl now.bowl our.bowl])
          ~
          ~
      ==
    =.  next-id.state  rfid
    =.  notebook-state  nb-state
    =.  books.state
      (~(put by books.state) flag [[%pub *log:notes] notebook-state])
    =.  se-core  (emit notebooks-changed-card)
    (se-update [%created nb %private])
  ::
  ::  +se-poke: dispatch a c-notes command to the right handler
  ++  se-poke
    |=  cmd=c-cmd:notes
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
    |=  cmd=c-cmd:notes
    ?>  ?=(%rename -.c-notebook.cmd)
    ^+  se-core
    ?>  (se-is-owner src.bowl)
    =/  nb=notebook:notes  notebook.notebook-state
    =.  nb  nb(title title.c-notebook.cmd, updated-at now.bowl, updated-by src.bowl)
    =.  notebook.notebook-state  nb
    (se-update [%updated nb])
  ::
  ++  se-delete-notebook
    |=  cmd=c-cmd:notes
    ?>  ?=(%delete -.c-notebook.cmd)
    ^+  se-core
    ?>  (se-is-owner src.bowl)
    ::  clean up published entries for this notebook
    =.  published.state
      %-  malt
      %+  skip  ~(tap by published.state)
      |=  [k=[=flag:notes note-id=@ud] v=@t]
      =(flag.k flag)
    ::  history and visibility live in notebook-state, deleted via gone flag
    =.  se-core  (se-update [%deleted ~])
    se-core(gone &)
  ::
  ++  se-set-visibility
    |=  cmd=c-cmd:notes
    ?>  ?=(%visibility -.c-notebook.cmd)
    ^+  se-core
    ?>  (se-is-owner src.bowl)
    =.  visibility.notebook-state  visibility.c-notebook.cmd
    (se-update [%visibility visibility.c-notebook.cmd])
  ::
  ++  se-invite
    |=  cmd=c-cmd:notes
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
    |=  cmd=c-cmd:notes
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
    |=  cmd=c-cmd:notes
    ?>  ?=(%member-leave -.c-notebook.cmd)
    ^+  se-core
    =.  members.notebook-state
      (~(del by members.notebook-state) src.bowl)
    (se-update [%member-left src.bowl])
  ::
  ++  se-dispatch-folder
    |=  cmd=c-cmd:notes
    ?>  ?=(%folder -.c-notebook.cmd)
    ^+  se-core
    =/  fid=@ud  id.c-notebook.cmd
    =/  fld-act=a-folder:notes  a-folder.c-notebook.cmd
    ?-  -.fld-act
      %rename  (se-rename-folder cmd)
      %move    (se-move-folder cmd)
      %delete  (se-delete-folder cmd)
    ==
  ::
  ++  se-dispatch-note
    |=  cmd=c-cmd:notes
    ?>  ?=(%note -.c-notebook.cmd)
    ^+  se-core
    =/  n-act=a-note:notes  a-note.c-notebook.cmd
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
    |=  cmd=c-cmd:notes
    ?>  ?=(%create-folder -.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  parent=(unit @ud)  parent.c-notebook.cmd
    =/  fid=@ud  +(next-id.state)
    =.  next-id.state  fid
    =/  nid=@ud  id.notebook.notebook-state
    =/  nf=folder:notes
      [fid nid name.c-notebook.cmd parent src.bowl now.bowl now.bowl src.bowl]
    =.  folders.notebook-state
      (~(put by folders.notebook-state) fid nf)
    (se-update [%folder fid [%created nf]])
  ::
  ++  se-rename-folder
    |=  cmd=c-cmd:notes
    ?>  ?=(%folder -.c-notebook.cmd)
    ?>  ?=(%rename -.a-folder.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  fid=@ud  id.c-notebook.cmd
    =/  fld=folder:notes
      (~(got by folders.notebook-state) fid)
    =.  fld  fld(name name.a-folder.c-notebook.cmd, updated-at now.bowl, updated-by src.bowl)
    =.  folders.notebook-state
      (~(put by folders.notebook-state) fid fld)
    (se-update [%folder fid [%updated fld]])
  ::
  ++  se-move-folder
    |=  cmd=c-cmd:notes
    ?>  ?=(%folder -.c-notebook.cmd)
    ?>  ?=(%move -.a-folder.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  fid=@ud  id.c-notebook.cmd
    =/  new-parent=@ud  new-parent.a-folder.c-notebook.cmd
    =/  fld=folder:notes
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
    |=  cmd=c-cmd:notes
    ?>  ?=(%folder -.c-notebook.cmd)
    ?>  ?=(%delete -.a-folder.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  fid=@ud  id.c-notebook.cmd
    =/  recursive=?  recursive.a-folder.c-notebook.cmd
    =/  fld=folder:notes
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
    =/  child-notes=(list note:notes)
      (se-notes-in-folder fid)
    ?>  =(~ child-notes)
    =.  folders.notebook-state
      (~(del by folders.notebook-state) fid)
    (se-update [%folder fid [%deleted ~]])
  ::
  ++  se-create-note
    |=  cmd=c-cmd:notes
    ?>  ?=(%create-note -.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  nid-nb=@ud  id.notebook.notebook-state
    =/  fid=@ud  folder.c-notebook.cmd
    =/  fld=folder:notes
      (~(got by folders.notebook-state) fid)
    =/  nid=@ud  +(next-id.state)
    =.  next-id.state  nid
    =/  nt=note:notes
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
    |=  cmd=c-cmd:notes
    ?>  ?=(%note -.c-notebook.cmd)
    ?>  ?=(%rename -.a-note.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  nid=@ud  id.c-notebook.cmd
    =/  nt=note:notes  (~(got by notes.notebook-state) nid)
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
    |=  cmd=c-cmd:notes
    ?>  ?=(%note -.c-notebook.cmd)
    ?>  ?=(%move -.a-note.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  nid=@ud  id.c-notebook.cmd
    =/  nt=note:notes  (~(got by notes.notebook-state) nid)
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
    |=  cmd=c-cmd:notes
    ?>  ?=(%note -.c-notebook.cmd)
    ?>  ?=(%delete -.a-note.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  nid=@ud  id.c-notebook.cmd
    =/  nt=note:notes
      (~(got by notes.notebook-state) nid)
    =.  notes.notebook-state
      (~(del by notes.notebook-state) nid)
    (se-update [%note nid [%deleted ~]])
  ::
  ++  se-update-note
    |=  cmd=c-cmd:notes
    ?>  ?=(%note -.c-notebook.cmd)
    ?>  ?=(%update -.a-note.c-notebook.cmd)
    ^+  se-core
    =/  nid=@ud  id.c-notebook.cmd
    =/  nt=note:notes
      (~(got by notes.notebook-state) nid)
    ?>  (se-can-edit src.bowl)
    ::  strict optimistic concurrency check (no force-update sentinel)
    ?:  !=(revision.nt expected-revision.a-note.c-notebook.cmd)
      ~|(%revision-mismatch !!)
    ::  no-op early-out: body unchanged
    ?:  =(body-md.nt body.a-note.c-notebook.cmd)
      se-core
    ::  archive the prior revision into per-notebook history
    =/  prior=note-revision:notes
      :*  rev=revision.nt
          at=now.bowl
          author=src.bowl
          title=title.nt
          body-md=body-md.nt
      ==
    =/  existing=(list note-revision:notes)
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
    |=  cmd=c-cmd:notes
    ?>  ?=(%note -.c-notebook.cmd)
    ?>  ?=(%restore -.a-note.c-notebook.cmd)
    ^+  se-core
    =/  nid=@ud  id.c-notebook.cmd
    =/  target-rev=@ud  rev.a-note.c-notebook.cmd
    =/  nt=note:notes
      (~(got by notes.notebook-state) nid)
    ?>  (se-can-edit src.bowl)
    ::  find the archived revision in per-notebook history
    =/  revs=(list note-revision:notes)
      (fall (~(get by history.notebook-state) nid) ~)
    =/  found=(unit note-revision:notes)
      |-
      ?~  revs  ~
      ?:  =(rev.i.revs target-rev)
        `i.revs
      $(revs t.revs)
    ?>  ?=(^ found)
    ::  apply as a normal update with current revision as expected
    (se-update-note `c-cmd:notes`[flag [%note nid [%update body-md.u.found revision.nt]]])
  ::
  ++  se-batch-import
    |=  cmd=c-cmd:notes
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
    =/  nt=note:notes
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
    |=  cmd=c-cmd:notes
    ?>  ?=(%batch-import-tree -.c-notebook.cmd)
    ^+  se-core
    ?>  (se-can-edit src.bowl)
    =/  items=(list import-node:notes)  tree.c-notebook.cmd
    =/  nid-nb=@ud  id.notebook.notebook-state
    =|  stack=(list [remaining=(list import-node:notes) folder-id=@ud])
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
      =/  nt=note:notes
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
      =/  nf=folder:notes
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
    |=  [fid=@ud fld=folder:notes]
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
    |=  [nid=@ud nt=note:notes]
    ?:  (~(has in fids) folder-id.nt)
      `nid
    ~
  ::
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
  ++  no-abed
    |=  f=flag:notes
    ^+  no-core
    ?~  entry=(~(get by books.state) f)
      ~|(no-abed-not-found+f !!)
    =/  [=net:notes =notebook-state:notes]  u.entry
    ?>  ?=(%sub -.net)
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
    |=  act=action:notes
    ^+  no-core
    ?>  ?=(%notebook -.act)
    =/  cmd=command:notes
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
    %-  emit
    [%pass no-sub-wire %agent [ship.flag %notes] %watch no-sub-path]
  ::
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
    |=  =response:notes
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
    |=  [=flag:notes upd=update:notes]
    ^+  no-core
    =/  u-nb=u-notebook:notes  u-notebook.upd
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
    |=  [fid=@ud upd=u-folder:notes]
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
    |=  [nid=@ud upd=u-note:notes]
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
      =/  existing=(list note-revision:notes)
        (fall (~(get by history.notebook-state) nid) ~)
      =.  history.notebook-state
        (~(put by history.notebook-state) nid [note-revision.upd existing])
      no-core
    ==
  --
--
