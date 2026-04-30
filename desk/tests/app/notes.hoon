::  tests/app/notes.hoon — behavior-level regression suite for %notes agent
::
::  Tests poke via %notes-action (a-notes) and assert via on-peek scry paths.
::  All pokes use the nested ACUR shape: top-level a-notes or
::  [%notebook =flag =a-notebook].
::
::  Multi-ship scenarios are NOT covered: test-agent.hoon is a single-bowl
::  harness with no cross-agent sign exchange.
::
/-  notes
/+  *test-agent, notes-json
/=  notes-agent  /app/notes
|%
++  dap  %notes
::
::  +poke-a: poke via %notes-action with a-notes value
++  poke-a
  |=  a=action:notes
  (do-poke %notes-action !>(a))
::
::  +init-zod: init agent as ~zod; discard cards
++  init-zod
  =/  m  (mare ,~)
  ^-  form:m
  ;<  ~  bind:m  (jab-bowl |=(=bowl bowl(our ~zod)))
  ;<  *  bind:m  (do-init dap notes-agent)
  (pure:m ~)
::
::  +nb-flag: flag for notebook n under ship who
++  nb-flag
  |=  [who=ship n=@ud]
  ^-  flag:notes
  [who (scot %ud n)]
::
::  peek helpers — no return type annotation (avoids form:(mare ,cage) issue)
::
++  peek-fld
  |=  [=flag:notes fid=@ud]
  =/  pax=path  /x/v0/folder/(scot %p ship.flag)/[name.flag]/(scot %ud fid)
  (got-peek pax)
::
++  peek-nt
  |=  [=flag:notes nid=@ud]
  =/  pax=path  /x/v0/note/(scot %p ship.flag)/[name.flag]/(scot %ud nid)
  (got-peek pax)
::
++  peek-mbrs
  |=  =flag:notes
  =/  pax=path  /x/v0/members/(scot %p ship.flag)/[name.flag]
  (got-peek pax)
::
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
::  +ex-cards-ne: assert at least one card was emitted
++  ex-cards-ne
  |=  caz=(list card)
  =/  m  (mare ,~)
  ^-  form:m
  |=  s=state
  ?~  caz
    |+['expected cards but got none']~
  &+[~ s]
::
::  +ex-json: assert cage has mark %json
++  ex-json
  |=  cag=cage
  =/  m  (mare ,~)
  ^-  form:m
  (ex-equal !>(p.cag) !>(`mark`%json))
::
::  +ex-gone: assert scry returns a null-json cage (item deleted/missing)
++  ex-gone
  |=  res=(unit (unit cage))
  =/  m  (mare ,~)
  ^-  form:m
  |=  s=state
  ?~  res
    |+['expected outer non-null scry result']~
  ?~  u.res
    |+['expected inner non-null cage (null-json)']~
  ?.  =(p.u.u.res %json)
    |+['expected mark %json for null-result']~
  ?.  =(0 q.q.u.u.res)
    |+['expected null json value (0)']~
  &+[~ s]
::
::  ====  test-create-notebook  ====
::  Creates notebook (id=1, root-folder=2); verifies folder and membership exist.
++  test-create-notebook
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  caz=(list card)  b  (poke-a [%create-notebook 'My Notebook'])
  ;<  ~  b  (ex-cards-ne caz)
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  root=cage  b  (peek-fld f 2)
  ;<  ~  b  (ex-json root)
  ;<  mbrs=cage  b  (peek-mbrs f)
  (ex-json mbrs)
::
::  ====  test-rename-notebook  ====
++  test-rename-notebook
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'Original'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  caz=(list card)  b  (poke-a [%notebook f [%rename 'Renamed']])
  ;<  ~  b  (ex-cards-ne caz)
  ;<  nb=cage  b  (got-peek /x/v0/notebook/(scot %p ship.f)/[name.f])
  (ex-json nb)
::
::  ====  test-delete-notebook  ====
++  test-delete-notebook
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'ToDelete'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  caz=(list card)  b  (poke-a [%notebook f [%delete ~]])
  ;<  ~  b  (ex-cards-ne caz)
  ;<  res=(unit (unit cage))  b
    (get-peek /x/v0/notebook/(scot %p ship.f)/[name.f])
  (ex-gone res)
::
::  ====  test-set-visibility-public  ====
++  test-set-visibility-public
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  caz=(list card)  b  (poke-a [%notebook f [%visibility %public]])
  (ex-cards-ne caz)
::
::  ====  test-join-public-accepts  ====
::  Non-member ~bus sends [%notes-command [flag [%member-join ~]]] to host (~zod);
::  must succeed and add ~bus as %editor.
++  test-join-public-accepts
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'Open NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%visibility %public]])
  ;<  *  b  (set-src ~bus)
  ;<  caz=(list card)  b
    (do-poke %notes-command !>(`command:notes`[%notebook f [%member-join ~]]))
  ;<  ~  b  (ex-cards-ne caz)
  ;<  *  b  (set-src our.bowl)
  ;<  mbrs=cage  b  (peek-mbrs f)
  (ex-json mbrs)
::
::  ====  test-join-private-rejects-non-member  ====
::  Non-member ~bus tries joining a private notebook — must crash.
++  test-join-private-rejects-non-member
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'Private NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (set-src ~bus)
  (ex-fail (do-poke %notes-command !>(`command:notes`[%notebook f [%member-join ~]])))
::
::  ====  test-create-folder-at-root  ====
++  test-create-folder-at-root
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  caz=(list card)  b  (poke-a [%notebook f [%create-folder `2 'Docs']])
  ;<  ~  b  (ex-cards-ne caz)
  ;<  fld=cage  b  (peek-fld f 3)
  (ex-json fld)
::
::  ====  test-create-folder-nested  ====
::  Sub-folder under Docs (id=3); new folder gets id=4.
++  test-create-folder-nested
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-folder `2 'Docs']])
  ;<  caz=(list card)  b  (poke-a [%notebook f [%create-folder `3 'Sub']])
  ;<  ~  b  (ex-cards-ne caz)
  ;<  sub=cage  b  (peek-fld f 4)
  (ex-json sub)
::
::  ====  test-rename-folder  ====
++  test-rename-folder
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-folder `2 'OldName']])
  ;<  caz=(list card)  b  (poke-a [%notebook f [%folder 3 [%rename 'NewName']]])
  (ex-cards-ne caz)
::
::  ====  test-move-folder  ====
::  FolderA(3) at root, FolderB(4) at root; move B under A.
++  test-move-folder
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-folder `2 'FolderA']])
  ;<  *  b  (poke-a [%notebook f [%create-folder `2 'FolderB']])
  ;<  caz=(list card)  b  (poke-a [%notebook f [%folder 4 [%move 3]]])
  (ex-cards-ne caz)
::
::  ====  test-delete-empty-folder-succeeds  ====
++  test-delete-empty-folder-succeeds
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-folder `2 'Empty']])
  ;<  caz=(list card)  b  (poke-a [%notebook f [%folder 3 [%delete %.n]]])
  ;<  ~  b  (ex-cards-ne caz)
  ;<  res=(unit (unit cage))  b
    =/  pax=path  /x/v0/folder/(scot %p ship.f)/[name.f]/(scot %ud 3)
    (get-peek pax)
  (ex-gone res)
::
::  ====  test-delete-nonempty-folder-nonrecursive-rejects  ====
++  test-delete-nonempty-folder-nonrecursive-rejects
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-folder `2 'HasNote']])
  ;<  *  b  (poke-a [%notebook f [%create-note 3 'Note' 'body']])
  (ex-fail (poke-a [%notebook f [%folder 3 [%delete %.n]]]))
::
::  ====  test-delete-nonempty-folder-recursive-succeeds  ====
++  test-delete-nonempty-folder-recursive-succeeds
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-folder `2 'HasNote']])
  ;<  *  b  (poke-a [%notebook f [%create-note 3 'Note' 'body']])
  ;<  caz=(list card)  b  (poke-a [%notebook f [%folder 3 [%delete %.y]]])
  ;<  ~  b  (ex-cards-ne caz)
  ;<  fld-res=(unit (unit cage))  b
    =/  pax=path  /x/v0/folder/(scot %p ship.f)/[name.f]/(scot %ud 3)
    (get-peek pax)
  ;<  ~  b  (ex-gone fld-res)
  ;<  nt-res=(unit (unit cage))  b
    =/  pax=path  /x/v0/note/(scot %p ship.f)/[name.f]/(scot %ud 4)
    (get-peek pax)
  (ex-gone nt-res)
::
::  ====  test-create-note  ====
++  test-create-note
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  caz=(list card)  b  (poke-a [%notebook f [%create-note 2 'Hello' '# Hello']])
  ;<  ~  b  (ex-cards-ne caz)
  ;<  nt=cage  b  (peek-nt f 3)
  (ex-json nt)
::
::  ====  test-rename-note  ====
++  test-rename-note
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-note 2 'OldTitle' 'body']])
  ;<  caz=(list card)  b  (poke-a [%notebook f [%note 3 [%rename 'NewTitle']]])
  (ex-cards-ne caz)
::
::  ====  test-move-note  ====
::  FolderA=id=3, note=id=4, FolderB=id=5; moves note from A to B.
++  test-move-note
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-folder `2 'FolderA']])
  ;<  *  b  (poke-a [%notebook f [%create-note 3 'MyNote' 'body']])
  ;<  *  b  (poke-a [%notebook f [%create-folder `2 'FolderB']])
  ;<  caz=(list card)  b  (poke-a [%notebook f [%note 4 [%move 5]]])
  (ex-cards-ne caz)
::
::  ====  test-update-note-matching-revision-succeeds  ====
::  Correct expected-revision: first edit (0→1) and second (1→2); both succeed.
++  test-update-note-matching-revision-succeeds
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-note 2 'Note' 'v1']])
  ;<  caz=(list card)  b  (poke-a [%notebook f [%note 3 [%update 'v2' 0]]])
  ;<  ~  b  (ex-cards-ne caz)
  ;<  caz=(list card)  b  (poke-a [%notebook f [%note 3 [%update 'v3' 1]]])
  (ex-cards-ne caz)
::
::  ====  test-update-note-mismatched-revision-rejects  ====
::  Stale expected-revision crashes; note still readable after.
++  test-update-note-mismatched-revision-rejects
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-note 2 'Note' 'v1']])
  ;<  *  b  (poke-a [%notebook f [%note 3 [%update 'v2' 0]]])
  ;<  *  b  (poke-a [%notebook f [%note 3 [%update 'v3' 1]]])
  ::  revision is now 2; expected-revision=1 is stale — must crash
  ;<  ~  b  (ex-fail (poke-a [%notebook f [%note 3 [%update 'v4' 1]]]))
  ;<  nt=cage  b  (peek-nt f 3)
  (ex-json nt)
::
::  ====  test-update-note-stale-zero-rejects  ====
::  expected-revision=0 on a note with revision>0 must crash (strict, no force-update).
++  test-update-note-stale-zero-rejects
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-note 2 'Note' 'v1']])
  ;<  *  b  (poke-a [%notebook f [%note 3 [%update 'v2' 0]]])
  ::  revision is now 1; expected-revision=0 is stale — must crash
  ;<  ~  b  (ex-fail (poke-a [%notebook f [%note 3 [%update 'clobbered' 0]]]))
  ;<  nt=cage  b  (peek-nt f 3)
  (ex-json nt)
::
::  ====  test-update-note-at-revision-zero-succeeds  ====
::  First edit (revision=0, expected=0) must succeed.
++  test-update-note-at-revision-zero-succeeds
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-note 2 'Note' 'initial']])
  ;<  caz=(list card)  b  (poke-a [%notebook f [%note 3 [%update 'first-edit' 0]]])
  (ex-cards-ne caz)
::
::  ====  test-delete-note  ====
++  test-delete-note
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-note 2 'ToDelete' 'body']])
  ;<  caz=(list card)  b  (poke-a [%notebook f [%note 3 [%delete ~]]])
  ;<  ~  b  (ex-cards-ne caz)
  ;<  res=(unit (unit cage))  b
    =/  pax=path  /x/v0/note/(scot %p ship.f)/[name.f]/(scot %ud 3)
    (get-peek pax)
  (ex-gone res)
::
::  ====  test-batch-import  ====
::  Imports 3 notes into root folder; ids 3, 4, 5 all exist.
++  test-batch-import
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  =/  items=(list [title=@t body=@t])
    ~[['Note1' 'body1'] ['Note2' 'body2'] ['Note3' 'body3']]
  ;<  caz=(list card)  b  (poke-a [%notebook f [%batch-import 2 items]])
  ;<  ~  b  (ex-cards-ne caz)
  ;<  n3=cage  b  (peek-nt f 3)
  ;<  ~  b  (ex-json n3)
  ;<  n4=cage  b  (peek-nt f 4)
  ;<  ~  b  (ex-json n4)
  ;<  n5=cage  b  (peek-nt f 5)
  (ex-json n5)
::
::  ====  test-batch-import-tree  ====
::  Subfolder Sub (id=3), NoteA (id=4), NoteB (id=5), Root (id=6).
++  test-batch-import-tree
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  =/  tree=(list import-node:notes)
    :~  [%folder 'Sub' ~[[%note 'NoteA' 'bodyA'] [%note 'NoteB' 'bodyB']]]
        [%note 'Root' 'rootbody']
    ==
  ;<  caz=(list card)  b  (poke-a [%notebook f [%batch-import-tree 2 tree]])
  ;<  ~  b  (ex-cards-ne caz)
  ;<  sub=cage   b  (peek-fld f 3)
  ;<  ~  b  (ex-json sub)
  ;<  na=cage    b  (peek-nt f 4)
  ;<  ~  b  (ex-json na)
  ;<  nb-c=cage  b  (peek-nt f 5)
  ;<  ~  b  (ex-json nb-c)
  ;<  nr=cage    b  (peek-nt f 6)
  (ex-json nr)
::
::  ====  test-publish-note  ====
++  test-publish-note
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-note 2 'Article' '# Hello']])
  ;<  *  b  (poke-a [%notebook f [%note 3 [%publish '<h1>Hello</h1>']]])
  ;<  pub=cage  b  (got-peek /x/v0/published)
  ;<  ~  b  (ex-json pub)
  ;<  *  b  (poke-a [%notebook f [%note 3 [%unpublish ~]]])
  ;<  pub2=cage  b  (got-peek /x/v0/published)
  (ex-json pub2)
::
::  ====  test-create-and-update-archives-prior-rev  ====
::  After a single update, history has exactly one entry containing
::  the prior body. The archive's rev is the rev the snapshot was at (0).
++  test-create-and-update-archives-prior-rev
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-note 2 'Note' 'v1']])
  ;<  *  b  (poke-a [%notebook f [%note 3 [%update 'v2' 0]]])
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
++  test-multiple-updates-newest-first
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-note 2 'Note' 'v1']])
  ;<  *  b  (poke-a [%notebook f [%note 3 [%update 'v2' 0]]])
  ;<  *  b  (poke-a [%notebook f [%note 3 [%update 'v3' 1]]])
  ;<  *  b  (poke-a [%notebook f [%note 3 [%update 'v4' 2]]])
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
++  test-noop-update-does-not-archive
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-note 2 'Note' 'same']])
  ;<  *  b  (poke-a [%notebook f [%note 3 [%update 'same' 0]]])
  (ex-history-len f 3 0)
::
::  ====  test-restore-via-update-archives-current  ====
::  "Restore" is an update with old content. After restoring 'v1' from
::  a v3 note, history has [v3, v2, v1].
++  test-restore-via-update-archives-current
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-note 2 'Note' 'v1']])
  ;<  *  b  (poke-a [%notebook f [%note 3 [%update 'v2' 0]]])
  ;<  *  b  (poke-a [%notebook f [%note 3 [%update 'v3' 1]]])
  ;<  *  b  (poke-a [%notebook f [%note 3 [%update 'v1' 2]]])
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
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-note 2 'Original' 'body']])
  ;<  *  b  (poke-a [%notebook f [%note 3 [%update 'edited' 0]]])
  ::  body update advanced rev to 1; rename must keep it at 1
  ;<  *  b  (poke-a [%notebook f [%note 3 [%rename 'Renamed']]])
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
++  test-history-empty-on-fresh-note
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-note 2 'Note' 'body']])
  (ex-history-len f 3 0)
::
::  ====  test-restore-action  ====
::  %restore looks up the archived body at rev=0 and re-applies it.
++  test-restore-action
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ;<  *  b  (poke-a [%create-notebook 'NB'])
  =/  f=flag:notes  (nb-flag our.bowl 1)
  ;<  *  b  (poke-a [%notebook f [%create-note 2 'Note' 'v1']])
  ;<  *  b  (poke-a [%notebook f [%note 3 [%update 'v2' 0]]])
  ;<  *  b  (poke-a [%notebook f [%note 3 [%update 'v3' 1]]])
  ::  restore to rev=0 (body 'v1')
  ;<  caz=(list card)  b  (poke-a [%notebook f [%note 3 [%restore 0]]])
  ;<  ~  b  (ex-cards-ne caz)
  ::  history should now have 3 entries (v1, v2, v3 archived)
  (ex-history-len f 3 3)
::
::  ====  test-accept-invite  ====
::  Seed a state-8 with an invite for a remote flag; accept clears the invite
::  and emits a join-remote card.
++  test-accept-invite
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  ::  build a state-8 with one invite pre-seeded
  =/  remote-flag=flag:notes  [~bus '5']
  =/  inv=(map flag:notes invite-info:notes)
    (~(put by *(map flag:notes invite-info:notes)) remote-flag [~bus now.bowl 'RemoteNB'])
  =/  s8=state-8:notes  [%8 ~ 0 ~ ~ inv ~]
  ;<  *  b  (do-load notes-agent `!>(s8))
  ::  accept: fires join-remote (emits a card) and removes invite
  ;<  caz=(list card)  b  (poke-a [%accept-invite remote-flag])
  ;<  ~  b  (ex-cards-ne caz)
  ::  invites map is now empty
  ;<  sv=vase  b  get-save
  =/  s8-after=state-8:notes  !<(state-8:notes sv)
  |=  s=state
  ?.  =(~ invites.s8-after)
    |+['expected empty invites map after accept-invite']~
  &+[~ s]
::
::  ====  test-decline-invite  ====
++  test-decline-invite
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ;<  =bowl:gall  b  get-bowl
  =/  remote-flag=flag:notes  [~bus '5']
  =/  inv=(map flag:notes invite-info:notes)
    (~(put by *(map flag:notes invite-info:notes)) remote-flag [~bus now.bowl 'RemoteNB'])
  =/  s8=state-8:notes  [%8 ~ 0 ~ ~ inv ~]
  ;<  *  b  (do-load notes-agent `!>(s8))
  ;<  *  b  (poke-a [%decline-invite remote-flag])
  ;<  sv=vase  b  get-save
  =/  s8-after=state-8:notes  !<(state-8:notes sv)
  |=  s=state
  ?.  =(~ invites.s8-after)
    |+['expected empty invites map after decline-invite']~
  &+[~ s]
::
::  ====  test-migrate-state-7-to-8  ====
::  Hand-built state-7 through on-load; result tag must be %8.
::  - updated-by backfilled on notebook from created-by
::  - pub log truncated to empty
::  - invites and history preserved
++  test-migrate-state-7-to-8
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  ::  Build state-7 with old-shape entities (notebook-v0, folder-v0)
  =/  nb=notebook-v0:notes  [1 'S7-NB' ~zod *@da *@da]
  =/  rf=folder-v0:notes    [2 1 '/' ~ ~zod *@da *@da]
  =/  mbrs=notebook-members:notes
    (~(put by *notebook-members:notes) ~zod %owner)
  =/  nb-s=notebook-state-v0:notes
    [nb mbrs (~(put by *(map @ud folder-v0:notes)) 2 rf) ~]
  =/  f=flag:notes  [~zod '1']
  =/  empty-bks  *(map flag:notes [net=net-v0:notes notebook-state=notebook-state-v0:notes])
  =/  bks  (~(put by empty-bks) f [[%pub *] nb-s])
  =/  empty-hist  *(map [=flag:notes note-id=@ud] (list note-revision:notes))
  =/  hist  (~(put by empty-hist) [[f 99]] ~[[0 *@da ~zod 'old' 'old-body']])
  =/  inv=(map flag:notes invite-info:notes)
    (~(put by *(map flag:notes invite-info:notes)) [~bus '3'] [~bus *@da 'invite'])
  =/  s7=state-7:notes
    [%7 bks 2 ~ ~ inv hist]
  ;<  *  b  (do-load notes-agent `!>(s7))
  ;<  sv=vase  b  get-save
  ;<  ~  b  (ex-equal !>(;;(@ -.q.sv)) !>(`@`%8))
  =/  s8=state-8:notes  !<(state-8:notes sv)
  |=  s=state
  ::  history preserved
  ?.  =(1 ~(wyt by history.s8))
    |+['expected history map preserved after state-7→8 migration']~
  ::  invites preserved
  ?.  =(1 ~(wyt by invites.s8))
    |+['expected invites map preserved after state-7→8 migration']~
  ::  pub log truncated
  =/  entry=[=net:notes =notebook-state:notes]  (~(got by books.s8) f)
  ?.  ?=(%pub -.net.entry)
    |+['expected %pub net']~
  ?.  =(~ (tap:log-on:notes log.net.entry))
    |+['expected empty pub log after state-7→8 migration']~
  &+[~ s]
::
::  ====  test-migrate-state-6-to-8  ====
++  test-migrate-state-6-to-8
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  =/  s6=state-6:notes  [%6 ~ 0 ~ ~ ~]
  ;<  *  b  (do-load notes-agent `!>(s6))
  ;<  sv=vase  b  get-save
  (ex-equal !>(;;(@ -.q.sv)) !>(`@`%8))
::
::  ====  test-migrate-state-6-preserves-notebook  ====
::  state-6 with one notebook migrates and the notebook is reachable.
++  test-migrate-state-6-preserves-notebook
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  =/  nb=notebook-v0:notes  [1 'Migrated' ~zod *@da *@da]
  =/  rf=folder-v0:notes    [2 1 '/' ~ ~zod *@da *@da]
  =/  mbrs=notebook-members:notes
    (~(put by *notebook-members:notes) ~zod %owner)
  =/  nb-s=notebook-state-v0:notes
    [nb mbrs (~(put by *(map @ud folder-v0:notes)) 2 rf) ~]
  =/  f=flag:notes  [~zod '1']
  =/  empty-bks  *(map flag:notes [net=net-v0:notes notebook-state=notebook-state-v0:notes])
  =/  bks  (~(put by empty-bks) f [[%pub *] nb-s])
  =/  s6=state-6:notes  [%6 bks 2 ~ ~ ~]
  ;<  *  b  (do-load notes-agent `!>(s6))
  ;<  nb-cag=cage  b  (got-peek /x/v0/notebook/(scot %p ~zod)/'1')
  (ex-json nb-cag)
::
::  ====  test-migrate-state-3-to-8  ====
++  test-migrate-state-3-to-8
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  =/  nb=notebook-v0:notes  [1 'S3-NB' ~zod *@da *@da]
  =/  rf=folder-v0:notes    [2 1 '/' ~ ~zod *@da *@da]
  =/  mbrs=notebook-members:notes
    (~(put by *notebook-members:notes) ~zod %owner)
  =/  nb-s=notebook-state-v0:notes
    [nb mbrs (~(put by *(map @ud folder-v0:notes)) 2 rf) ~]
  =/  f=flag:notes  [~zod '1']
  =/  empty-bks  *(map flag:notes [net=net-v0:notes notebook-state=notebook-state-v0:notes])
  =/  bks  (~(put by empty-bks) f [[%pub *] nb-s])
  =/  s3=state-3:notes  [%3 bks 2 ~]
  ;<  *  b  (do-load notes-agent `!>(s3))
  ;<  sv=vase  b  get-save
  (ex-equal !>(;;(@ -.q.sv)) !>(`@`%8))
::
::  ====  test-migrate-state-2-to-8  ====
::  state-2 published (bare @ud key) is dropped; published in state-8 is empty.
++  test-migrate-state-2-to-8
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  =/  nb=notebook-v0:notes  [1 'S2-NB' ~zod *@da *@da]
  =/  rf=folder-v0:notes    [2 1 '/' ~ ~zod *@da *@da]
  =/  mbrs=notebook-members:notes
    (~(put by *notebook-members:notes) ~zod %owner)
  =/  nb-s=notebook-state-v0:notes
    [nb mbrs (~(put by *(map @ud folder-v0:notes)) 2 rf) ~]
  =/  f=flag:notes  [~zod '1']
  =/  empty-bks  *(map flag:notes [net=net-v0:notes notebook-state=notebook-state-v0:notes])
  =/  bks  (~(put by empty-bks) f [[%pub *] nb-s])
  =/  s2=state-2:notes
    [%2 bks 2 (~(put by *(map @ud @t)) 1 '<h1>Old</h1>')]
  ;<  *  b  (do-load notes-agent `!>(s2))
  ;<  sv=vase  b  get-save
  ;<  ~  b  (ex-equal !>(;;(@ -.q.sv)) !>(`@`%8))
  ;<  pub=cage  b  (got-peek /x/v0/published)
  ;<  ~  b  (ex-json pub)
  =/  jv=json  !<(json q.pub)
  |=  s=state
  ?.  ?=([%a ~] jv)
    |+['expected empty json array for published after state-2 migration']~
  &+[~ s]
::
::  ====  test-migrate-state-1-to-8  ====
++  test-migrate-state-1-to-8
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  =/  nb=notebook-v0:notes  [1 'S1-NB' ~zod *@da *@da]
  =/  rf=folder-v0:notes    [2 1 '/' ~ ~zod *@da *@da]
  =/  mbrs=notebook-members:notes
    (~(put by *notebook-members:notes) ~zod %owner)
  =/  nb-s=notebook-state-v0:notes
    [nb mbrs (~(put by *(map @ud folder-v0:notes)) 2 rf) ~]
  =/  f=flag:notes  [~zod '1']
  =/  empty-bks  *(map flag:notes [net=net-v0:notes notebook-state=notebook-state-v0:notes])
  =/  bks  (~(put by empty-bks) f [[%pub *] nb-s])
  =/  s1=state-1:notes  [%1 bks 2]
  ;<  *  b  (do-load notes-agent `!>(s1))
  ;<  sv=vase  b  get-save
  (ex-equal !>(;;(@ -.q.sv)) !>(`@`%8))
::
::  ====  test-migrate-state-4-backfills-updated-by  ====
::  state-4: notebook and folders lack updated-by; migration backfills from created-by.
++  test-migrate-state-4-backfills-updated-by
  %-  eval-mare
  =/  m  (mare ,~)
  =*  b  bind:m
  ^-  form:m
  ;<  ~  b  init-zod
  =/  nb=notebook-v0:notes  [1 'S4-NB' ~nec *@da *@da]
  =/  rf=folder-v0:notes    [2 1 '/' ~ ~nec *@da *@da]
  =/  cf=folder-v0:notes    [3 1 'Child' `2 ~nec *@da *@da]
  =/  nt=note:notes
    :*  4  1  2  'MyNote'  ~  'body'
        ~nec  *@da  ~bus  *@da  0
    ==
  =/  mbrs=notebook-members:notes
    (~(put by *notebook-members:notes) ~nec %owner)
  =/  fldmap  *(map @ud folder-v0:notes)
  =.  fldmap  (~(put by fldmap) 2 rf)
  =.  fldmap  (~(put by fldmap) 3 cf)
  =/  ntmap=(map @ud note:notes)
    (~(put by *(map @ud note:notes)) 4 nt)
  =/  nb-s=notebook-state-v0:notes
    [nb mbrs fldmap ntmap]
  =/  f=flag:notes  [~zod '1']
  =/  empty-bks  *(map flag:notes [net=net-v0:notes notebook-state=notebook-state-v0:notes])
  =/  bks  (~(put by empty-bks) f [[%pub *] nb-s])
  =/  s4=state-4:notes  [%4 bks 4 ~ ~]
  ;<  *  b  (do-load notes-agent `!>(s4))
  ;<  sv=vase  b  get-save
  ;<  ~  b  (ex-equal !>(;;(@ -.q.sv)) !>(`@`%8))
  =/  s8=state-8:notes  !<(state-8:notes sv)
  =/  entry=[=net:notes =notebook-state:notes]  (~(got by books.s8) f)
  =/  migrated-nb-s=notebook-state:notes  notebook-state.entry
  |=  s=state
  ?.  =(~nec updated-by.notebook.migrated-nb-s)
    |+['expected notebook updated-by backfilled from created-by']~
  =/  mig-rf=folder:notes  (~(got by folders.migrated-nb-s) 2)
  ?.  =(~nec updated-by.mig-rf)
    |+['expected root folder updated-by backfilled']~
  =/  mig-cf=folder:notes  (~(got by folders.migrated-nb-s) 3)
  ?.  =(~nec updated-by.mig-cf)
    |+['expected child folder updated-by backfilled']~
  =/  mig-nt=note:notes  (~(got by notes.migrated-nb-s) 4)
  ?.  =(~bus updated-by.mig-nt)
    |+['expected note updated-by preserved (~bus)']~
  &+[~ s]
::
::  ====  JSON wire-format tests  ============================================
::  These hit notes-json directly without booting the agent. They guard the
::  UI ↔ agent contract (field names, nesting, envelope shape).
::
::  +mk-pairs / +mk-num / +mk-str / +mk-arr — concise json builders.
++  mk-str  |=(s=@t [%s s])
++  mk-num  |=(n=@ud (numb:enjs:format n))
++  mk-arr  |=(items=(list json) [%a items])
++  mk-obj  |=(kvs=(list [@t json]) (pairs:enjs:format kvs))
::
::  ====  test-json-decode-create-notebook  ====
++  test-json-decode-create-notebook
  %-  eval-mare
  =/  m  (mare ,~)
  ^-  form:m
  =/  jon=json
    %-  mk-obj
    :~  ['type' [%s 'create-notebook']]
        ['title' [%s 'My Book']]
    ==
  =/  parsed=action:notes  (action:dejs:notes-json jon)
  =/  expected=action:notes  [%create-notebook 'My Book']
  (ex-equal !>(parsed) !>(expected))
::
::  ====  test-json-decode-join  ====
++  test-json-decode-join
  %-  eval-mare
  =/  m  (mare ,~)
  ^-  form:m
  =/  jon=json
    %-  mk-obj
    :~  ['type' [%s 'join']]
        ['ship' [%s '~zod']]
        ['name' [%s 'foo']]
    ==
  =/  parsed=action:notes  (action:dejs:notes-json jon)
  =/  expected=action:notes  [%join [~zod 'foo']]
  (ex-equal !>(parsed) !>(expected))
::
::  ====  test-json-decode-accept-invite  ====
++  test-json-decode-accept-invite
  %-  eval-mare
  =/  m  (mare ,~)
  ^-  form:m
  =/  jon=json
    %-  mk-obj
    :~  ['type' [%s 'accept-invite']]
        ['ship' [%s '~bus']]
        ['name' [%s 'shared']]
    ==
  =/  parsed=action:notes  (action:dejs:notes-json jon)
  =/  expected=action:notes  [%accept-invite [~bus 'shared']]
  (ex-equal !>(parsed) !>(expected))
::
::  Note: %notify-invite moved from a-notes to c-notes (it's a cross-ship
::  message, not a local UI action). Commands aren't JSON-decoded —
::  they're noun-encoded between agents — so there's no test-agent
::  decode test for notify-invite here. The cross-ship-invite Playwright
::  spec exercises the round-trip end-to-end.
::
::  ====  test-json-decode-notebook-rename  ====
++  test-json-decode-notebook-rename
  %-  eval-mare
  =/  m  (mare ,~)
  ^-  form:m
  =/  inner=json
    %-  mk-obj
    :~  ['type' [%s 'rename']]
        ['title' [%s 'New Name']]
    ==
  =/  jon=json
    %-  mk-obj
    :~  ['type' [%s 'notebook']]
        ['flag' [%s '~zod/foo']]
        ['action' inner]
    ==
  =/  parsed=action:notes  (action:dejs:notes-json jon)
  =/  expected=action:notes  [%notebook [~zod 'foo'] [%rename 'New Name']]
  (ex-equal !>(parsed) !>(expected))
::
::  ====  test-json-decode-folder-rename-nested  ====
::  Three-level nesting: notebook → folder id → folder action.
++  test-json-decode-folder-rename-nested
  %-  eval-mare
  =/  m  (mare ,~)
  ^-  form:m
  =/  fld=json
    %-  mk-obj
    :~  ['type' [%s 'rename']]
        ['name' [%s 'docs']]
    ==
  =/  inner=json
    %-  mk-obj
    :~  ['type' [%s 'folder']]
        ['id' (mk-num 7)]
        ['action' fld]
    ==
  =/  jon=json
    %-  mk-obj
    :~  ['type' [%s 'notebook']]
        ['flag' [%s '~zod/foo']]
        ['action' inner]
    ==
  =/  parsed=action:notes  (action:dejs:notes-json jon)
  =/  expected=action:notes
    [%notebook [~zod 'foo'] [%folder 7 [%rename 'docs']]]
  (ex-equal !>(parsed) !>(expected))
::
::  ====  test-json-decode-note-update-nested  ====
++  test-json-decode-note-update-nested
  %-  eval-mare
  =/  m  (mare ,~)
  ^-  form:m
  =/  nt=json
    %-  mk-obj
    :~  ['type' [%s 'update']]
        ['body' [%s '# Hello']]
        ['expectedRevision' (mk-num 3)]
    ==
  =/  inner=json
    %-  mk-obj
    :~  ['type' [%s 'note']]
        ['id' (mk-num 12)]
        ['action' nt]
    ==
  =/  jon=json
    %-  mk-obj
    :~  ['type' [%s 'notebook']]
        ['flag' [%s '~zod/foo']]
        ['action' inner]
    ==
  =/  parsed=action:notes  (action:dejs:notes-json jon)
  =/  expected=action:notes
    [%notebook [~zod 'foo'] [%note 12 [%update '# Hello' 3]]]
  (ex-equal !>(parsed) !>(expected))
::
::  ====  test-json-decode-batch-import-flat  ====
::  Notes use `body` (not `bodyMd`) on the wire.
++  test-json-decode-batch-import-flat
  %-  eval-mare
  =/  m  (mare ,~)
  ^-  form:m
  =/  n1=json
    (mk-obj ~[['title' [%s 'a']] ['body' [%s 'A body']]])
  =/  n2=json
    (mk-obj ~[['title' [%s 'b']] ['body' [%s 'B body']]])
  =/  inner=json
    %-  mk-obj
    :~  ['type' [%s 'batch-import']]
        ['folder' (mk-num 2)]
        ['notes' (mk-arr ~[n1 n2])]
    ==
  =/  jon=json
    %-  mk-obj
    :~  ['type' [%s 'notebook']]
        ['flag' [%s '~zod/foo']]
        ['action' inner]
    ==
  =/  parsed=action:notes  (action:dejs:notes-json jon)
  =/  expected=action:notes
    :*  %notebook
        [~zod 'foo']
        :*  %batch-import
            2
            ~[[title='a' body='A body'] [title='b' body='B body']]
        ==
    ==
  (ex-equal !>(parsed) !>(expected))
::
::  ====  test-json-decode-batch-import-tree  ====
::  REGRESSION: tree note nodes use `body` (not `bodyMd`). Bug shipped briefly
::  where the tree builder sent bodyMd while the decoder expected body.
++  test-json-decode-batch-import-tree
  %-  eval-mare
  =/  m  (mare ,~)
  ^-  form:m
  =/  leaf=json
    (mk-obj ~[['title' [%s 'README']] ['body' [%s 'hello']]])
  =/  sub-folder=json
    %-  mk-obj
    :~  ['name' [%s 'sub']]
        ['children' (mk-arr ~[leaf])]
    ==
  =/  inner=json
    %-  mk-obj
    :~  ['type' [%s 'batch-import-tree']]
        ['parent' (mk-num 2)]
        ['tree' (mk-arr ~[sub-folder])]
    ==
  =/  jon=json
    %-  mk-obj
    :~  ['type' [%s 'notebook']]
        ['flag' [%s '~zod/foo']]
        ['action' inner]
    ==
  =/  parsed=action:notes  (action:dejs:notes-json jon)
  =/  expected=action:notes
    :*  %notebook
        [~zod 'foo']
        :*  %batch-import-tree
            2
            ~[[%folder 'sub' ~[[%note 'README' 'hello']]]]
        ==
    ==
  (ex-equal !>(parsed) !>(expected))
::
::  ====  test-json-decode-create-folder  ====
::  parent is (unit @ud); null in JSON → ~ in Hoon.
++  test-json-decode-create-folder-no-parent
  %-  eval-mare
  =/  m  (mare ,~)
  ^-  form:m
  =/  inner=json
    %-  mk-obj
    :~  ['type' [%s 'create-folder']]
        ['parent' ~]
        ['name' [%s 'docs']]
    ==
  =/  jon=json
    %-  mk-obj
    :~  ['type' [%s 'notebook']]
        ['flag' [%s '~zod/foo']]
        ['action' inner]
    ==
  =/  parsed=action:notes  (action:dejs:notes-json jon)
  =/  expected=action:notes
    [%notebook [~zod 'foo'] [%create-folder ~ 'docs']]
  (ex-equal !>(parsed) !>(expected))
::
::  ====  test-json-decode-create-folder-with-parent  ====
++  test-json-decode-create-folder-with-parent
  %-  eval-mare
  =/  m  (mare ,~)
  ^-  form:m
  =/  inner=json
    %-  mk-obj
    :~  ['type' [%s 'create-folder']]
        ['parent' (mk-num 2)]
        ['name' [%s 'subdir']]
    ==
  =/  jon=json
    %-  mk-obj
    :~  ['type' [%s 'notebook']]
        ['flag' [%s '~zod/foo']]
        ['action' inner]
    ==
  =/  parsed=action:notes  (action:dejs:notes-json jon)
  =/  expected=action:notes
    [%notebook [~zod 'foo'] [%create-folder `2 'subdir']]
  (ex-equal !>(parsed) !>(expected))
::
::  ====  JSON encoder tests  ===============================================
::
::  ====  test-json-encode-snapshot-carries-visibility  ====
::  Regression: snapshot must include visibility so subscribers can seed it.
++  test-json-encode-snapshot-carries-visibility
  %-  eval-mare
  =/  m  (mare ,~)
  ^-  form:m
  |=  s=state
  =/  nb=notebook:notes
    [1 'Test' ~zod ~1970.1.1 ~1970.1.1 ~zod]
  =/  nb-s=notebook-state:notes  [nb ~ ~ ~]
  =/  res=response:notes  [%snapshot [~zod 'foo'] %public nb-s]
  =/  jon=json  (response:enjs:notes-json res)
  ?.  ?=([%o *] jon)
    |+['expected json object']~
  =/  vis=(unit json)  (~(get by p.jon) 'visibility')
  ?~  vis
    |+['snapshot missing visibility field']~
  &+[~ s]
::
--
