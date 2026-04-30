::  tests/app/notes.hoon — backend tests for %notes
::
::  Single-bowl harness via /+ test-agent. Pokes via %notes-action with a
::  routed-action envelope; assertions go through on-peek scry paths.
::
::  No multi-ship scenarios — those would need cross-agent sign exchange,
::  which test-agent doesn't simulate. We rely on integration testing on
::  the dev ship for the host/subscriber flow.
::
/-  notes
/+  *test-agent
/=  notes-agent  /app/notes
|%
++  dap  %notes
::
::  +nb-flag: flag for notebook n on ship who
++  nb-flag
  |=  [who=ship n=@ud]
  ^-  flag:notes
  [who (scot %ud n)]
::
::  +poke-ra: poke %notes-action with a bare action (target=~)
++  poke-ra
  |=  a=action:notes
  =/  ra=routed-action:notes  [~ a]
  (do-poke %notes-action !>(ra))
::
::  +init-zod: init agent as ~zod, discarding cards
++  init-zod
  =/  m  (mare ,~)
  ^-  form:m
  ;<  ~  bind:m  (jab-bowl |=(=bowl bowl(our ~zod)))
  ;<  *  bind:m  (do-init dap notes-agent)
  (pure:m ~)
::
::  +ex-json: cage mark must be %json
++  ex-json
  |=  cag=cage
  =/  m  (mare ,~)
  ^-  form:m
  (ex-equal !>(p.cag) !>(`mark`%json))
::
::  +peek-history: scry /v0/note-history/<host>/<name>/<id>, return list
::  Agent returns json+!>([%a items]); we return the items.
++  peek-history
  |=  [=flag:notes nid=@ud]
  =/  m  (mare ,(list json))
  ^-  form:m
  =/  pax=path
    /x/v0/note-history/(scot %p ship.flag)/[name.flag]/(scot %ud nid)
  |=  s=state
  =/  peek=(unit (unit cage))  (~(on-peek agent.s bowl.s) pax)
  ?~  peek  |+~['scry path invalid: history']
  ?~  u.peek  |+~['scry path empty: history']
  =/  cag=cage  u.u.peek
  ?.  =(p.cag %json)  |+~['expected json mark for history scry']
  =/  jv=json  !<(json q.cag)
  ?.  ?=([%a *] jv)  |+~['expected json array for history scry']
  &+[p.jv s]
::
::  +ex-history-len: assert history scry returned exactly n entries
++  ex-history-len
  |=  [=flag:notes nid=@ud n=@ud]
  =/  m  (mare ,~)
  ^-  form:m
  ;<  items=(list json)  bind:m  (peek-history flag nid)
  |=  s=state
  =/  got=@ud  (lent items)
  ?:  =(got n)
    &+[~ s]
  |+~[(crip "expected {<n>} history entries, got {<got>}")]
::
::  +get-history-bodies: extract bodyMd strings, in returned order
++  get-history-bodies
  |=  items=(list json)
  ^-  (list @t)
  %+  turn  items
  |=  jv=json
  ?.  ?=([%o *] jv)  ''
  =/  body=(unit json)  (~(get by p.jv) 'bodyMd')
  ?~  body  ''
  ?.  ?=([%s *] u.body)  ''
  p.u.body
::
::  +get-history-revs: extract rev numbers from history items
++  get-history-revs
  |=  items=(list json)
  ^-  (list @ud)
  %+  turn  items
  |=  jv=json
  ?.  ?=([%o *] jv)  0
  =/  r=(unit json)  (~(get by p.jv) 'rev')
  ?~  r  0
  ?.  ?=([%n *] u.r)  0
  (rash p.u.r dem)
::
::  ====  test-create-and-update-archives-prior-rev  ====
::  After a single update, history has exactly one entry containing
::  the prior body. The archive's rev is the rev the snapshot was at
::  (0), not the new rev that replaced it (1).
++  test-create-and-update-archives-prior-rev
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-ra [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ::  notebook id=1, root folder id=2, note id=3
  ;<  *  b  (poke-ra [%create-note 1 2 'Note' 'v1'])
  ;<  *  b  (poke-ra [%update-note 1 3 'v2' 0])
  ;<  ~  b  (ex-history-len f 3 1)
  ;<  items=(list json)  b  (peek-history f 3)
  =/  bodies=(list @t)  (get-history-bodies items)
  =/  revs=(list @ud)  (get-history-revs items)
  |=  s=state
  ?.  =(['v1' ~] bodies)
    |+~[(crip "expected ['v1'], got {<bodies>}")]
  ?.  =(`(list @ud)`~[0] revs)
    |+~[(crip "expected revs=[0], got {<revs>}")]
  &+[~ s]
::
::  ====  test-multiple-updates-newest-first  ====
::  Three updates produce three archive entries newest-first.
::  Each entry holds the body that was REPLACED at that revision,
::  tagged with the rev that body was at (newest-first: 2, 1, 0).
++  test-multiple-updates-newest-first
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-ra [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-ra [%create-note 1 2 'Note' 'v1'])
  ;<  *  b  (poke-ra [%update-note 1 3 'v2' 0])
  ;<  *  b  (poke-ra [%update-note 1 3 'v3' 1])
  ;<  *  b  (poke-ra [%update-note 1 3 'v4' 2])
  ;<  ~  b  (ex-history-len f 3 3)
  ;<  items=(list json)  b  (peek-history f 3)
  =/  bodies=(list @t)  (get-history-bodies items)
  =/  revs=(list @ud)  (get-history-revs items)
  |=  s=state
  ?.  =(['v3' 'v2' 'v1' ~] bodies)
    |+~[(crip "expected ['v3' 'v2' 'v1'], got {<bodies>}")]
  ?.  =(`(list @ud)`~[2 1 0] revs)
    |+~[(crip "expected revs=[2 1 0], got {<revs>}")]
  &+[~ s]
::
::  ====  test-noop-update-does-not-archive  ====
::  An update with body identical to current is a no-op: no archive,
::  no revision bump.
++  test-noop-update-does-not-archive
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-ra [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-ra [%create-note 1 2 'Note' 'same'])
  ;<  *  b  (poke-ra [%update-note 1 3 'same' 0])
  (ex-history-len f 3 0)
::
::  ====  test-restore-via-update-archives-current  ====
::  "Restore" is just a regular update-note with the old content.
::  After restoring 'v1' from a v3 note, history has [v3, v2, v1].
++  test-restore-via-update-archives-current
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-ra [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-ra [%create-note 1 2 'Note' 'v1'])
  ;<  *  b  (poke-ra [%update-note 1 3 'v2' 0])
  ;<  *  b  (poke-ra [%update-note 1 3 'v3' 1])
  ;<  *  b  (poke-ra [%update-note 1 3 'v1' 2])
  ;<  ~  b  (ex-history-len f 3 3)
  ;<  items=(list json)  b  (peek-history f 3)
  =/  bodies=(list @t)  (get-history-bodies items)
  |=  s=state
  ?.  =(['v3' 'v2' 'v1' ~] bodies)
    |+~[(crip "expected ['v3' 'v2' 'v1'], got {<bodies>}")]
  &+[~ s]
::
::  ====  test-rename-does-not-bump-revision  ====
::  rename-note must not bump the body-md revision counter, otherwise an
::  autoSave sequence that fires update-note then rename-note silently
::  desyncs the client's expected-revision from the server's actual rev,
::  causing later saves to fail with revision-mismatch and lose work.
++  test-rename-does-not-bump-revision
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-ra [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-ra [%create-note 1 2 'Original' 'body'])
  ;<  *  b  (poke-ra [%update-note 1 3 'edited' 0])
  ::  body update advanced rev to 1; rename must keep it at 1
  ;<  *  b  (poke-ra [%rename-note 1 3 'Renamed'])
  ;<  nt=cage  b
    (got-peek /x/v0/note/(scot %p ship.f)/[name.f]/'3')
  |=  s=state
  =/  jv=json  !<(json q.nt)
  ?.  ?=([%o *] jv)
    |+['expected note json object']~
  =/  rev-j=(unit json)  (~(get by p.jv) 'revision')
  ?~  rev-j  |+['expected revision field']~
  ?.  ?=([%n *] u.rev-j)  |+['expected revision to be a number']~
  =/  rev=@ud  (rash p.u.rev-j dem)
  ?.  =(rev 1)
    |+~[(crip "expected rev=1 after update+rename, got rev={<rev>}")]
  &+[~ s]
::
::  ====  test-history-empty-on-fresh-note  ====
::  A note that has never been updated has empty history.
++  test-history-empty-on-fresh-note
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-ra [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-ra [%create-note 1 2 'Note' 'body'])
  (ex-history-len f 3 0)
::
::  ====  test-migrate-state-6-to-7  ====
::  Hand-built state-6 through on-load; result tag is %7 and the
::  history map is empty.
++  test-migrate-state-6-to-7
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  =/  s6=state-6:notes  [%6 ~ 0 ~ ~ ~]
  ;<  *  b  (do-load notes-agent `!>(s6))
  ;<  sv=vase  b  get-save
  ;<  ~  b  (ex-equal !>(;;(@ -.q.sv)) !>(`@`%7))
  =/  s7=state-7:notes  !<(state-7:notes sv)
  |=  s=state
  ?.  =(~ history.s7)
    |+['expected empty history map after state-6→7 migration']~
  &+[~ s]
::
::  ====  test-migrate-preserves-existing-notebook  ====
::  state-6 with one notebook migrates and the notebook is reachable.
++  test-migrate-preserves-existing-notebook
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  =/  nb=notebook:notes  [1 'Migrated' ~zod *@da *@da]
  =/  rf=folder:notes    [2 1 '/' ~ ~zod *@da *@da]
  =/  mbrs=notebook-members:notes
    (~(put by *notebook-members:notes) ~zod %owner)
  =/  nb-s=notebook-state:notes
    [nb mbrs (~(put by *(map @ud folder:notes)) 2 rf) ~]
  =/  f=flag:notes  [~zod '1']
  =/  bks=(map flag:notes [=net:notes =notebook-state:notes])
    %-  ~(put by *(map flag:notes [=net:notes =notebook-state:notes]))
    [f [[%pub *log:notes] nb-s]]
  =/  s6=state-6:notes  [%6 bks 2 ~ ~ ~]
  ;<  *  b  (do-load notes-agent `!>(s6))
  ;<  nb-cag=cage  b  (got-peek /x/v0/notebook/(scot %p ~zod)/'1')
  (ex-json nb-cag)
--
