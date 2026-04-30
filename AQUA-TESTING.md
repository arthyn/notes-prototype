# Aqua Testing Plan

A staged plan for adding cross-ship integration tests to `%notes` using
Urbit's aqua (multi-ship simulation) framework. Reference: tloncorp/tlon-apps
PR #5692 ("Aqua tests: lure & others") which added a 3-ship onboarding test
to the existing single-bowl test suite.

## Why we want it

Our existing test surface has three layers:

1. **Backend behavior** (`desk/tests/app/notes.hoon`, 52 tests) — runs in the
   `test-agent` single-bowl harness. Pokes the agent, scries it, asserts
   state. Fast, no setup.
2. **JSON wire format** (12 of those 52 tests) — exercises the
   `dejs`/`enjs` arms in `lib/notes-json.hoon` directly.
3. **Frontend pure functions** (`tests/frontend/run.html`, ~28 tests) —
   action envelope helpers, dispatch routing, route parsing, notebook
   keying. Opened in a browser.

What none of those reach: **real cross-ship traffic**. The `test-agent`
harness is a single bowl; it can't simulate two agents exchanging signs
over the network. So every cross-ship feature ends up tested manually by
running two ships and clicking through the UI.

The bugs we hit this session were almost all in that gap:

- `%notify-invite` collapsing into the notebook-scoped `%invite` arm and
  crashing the host-only assertion on the recipient.
- `r-notes %snapshot` not carrying `visibility`, so subscribers seeded
  `visibilities.state` empty and showed remote public notebooks as
  private.
- `applyNotebookUpdate` silently dropping `notebooks-changed`, so newly
  joined notebooks didn't appear without a refresh.
- Two-subscriber race on `%update-note` masked by eyre PUT returning OK
  before the agent rejected — fixed in v0.9.0 master with poke-ack
  tracking.

Every one of these would have been caught by an aqua test that does
"`~zod` pokes `~bud`'s `%notes`, expect fact on `~bud`'s inbox stream".

## What aqua actually is

Aqua boots N virtual ships inside one host process. Each virtual ship has
its own Arvo, its own state, its own duct identity. They exchange real
Arvo signs (no IP packets, but real `%pass`/`%give` flow). The
`ph-io`/`ph-test` strand libraries provide combinators for orchestrating
multi-ship scenarios:

- `(poke-app [ship %app] cage)` — issue a poke from an aqua ship.
- `(watch-app /path [ship %app] /sub-path)` — start a subscription.
- `(wait-for-app-fact /path [ship %app])` — block until the next fact
  arrives on a path; returns the cage.
- `(scry-aqua type ship path)` — scry a virtual ship.
- `(ex-equal !>(a) !>(b))` — assert vase equality (same as test-agent).

Each test is a strand: `++  test-foo  =/  m  (strand ,~)  ^-  form:m  ...`.

## Recommended hybrid model

**Don't replace the test-agent suite.** It's fast (microsecond test
loop), covers everything single-bowl, and we have 52 tests already.

**Add a small aqua suite alongside.** ~5–8 tests covering only what
test-agent can't reach. Each test maps to a manual smoke we run today.

```
desk/tests/app/notes.hoon         <- existing 52 test-agent tests (single bowl)
desk/tests/ph/for/notes.hoon      <- new aqua tests (multi-ship)
```

## Concrete test list

These are the cross-ship behaviors that have produced bugs and that
aqua can verify:

1. **`test-cross-ship-invite-flow`** — `~zod` creates a public notebook,
   pokes itself with `[%notebook flag [%invite who=~bud]]`. Expect:
   `~bud` receives a `%notify-invite` poke; `~bud`'s `invites.state`
   has the flag; `~bud`'s `/v0/inbox/stream` emits an `invite-received`
   fact.
2. **`test-cross-ship-accept-invite-snapshot-seeds-visibility`** — `~bud`
   accepts the invite; pokes `~zod` with `[%member-join ~]`; subscribes
   to `~zod`'s `/updates`; receives initial snapshot. Expect: `~bud`'s
   scry of `/v0/notebooks` returns `"visibility":"public"` for that
   flag. (Regression for the snapshot-visibility bug.)
3. **`test-cross-ship-visibility-toggle-propagates`** — `~zod` flips
   visibility to private. `~bud`'s `no-apply-update %visibility` should
   write the new value. Expect: `~bud`'s scry flips. (Regression for
   the live-toggle bug.)
4. **`test-cross-ship-note-update-propagates`** — `~bud` updates a note
   (sends `%c-notebook %note %update`). Expect: `~zod`'s state reflects
   the new body and revision; both ships' `/v0/notes/<flag>/stream`
   subscribers see the `%note %updated` fact.
5. **`test-cross-ship-revision-conflict-rejects`** — `~bud` and `~fen`
   both subscribe and both fire updates with the same
   `expected-revision`. Expect: one succeeds, the other gets a
   poke-nack carrying `%revision-mismatch`. (Verifies master's
   poke-ack-tracking semantics.)
6. **`test-cross-ship-leave-rejoin-fresh-snapshot`** — `~bud` leaves,
   then re-joins. Expect: clean state on `~bud`; second snapshot
   carries current visibility + members; no leftover entry from before
   leave.
7. **`test-cross-ship-subscription-kick-resub`** — simulate `%kick` on
   `~bud`'s subscription to `~zod`. Expect: `no-agent %kick` arm fires;
   `~bud` re-watches; subsequent updates from `~zod` still arrive.

Optional but nice:

8. **`test-cross-ship-decline-invite-clears`** — invite then decline;
   verify `give-inbox-removed` flows.
9. **`test-cross-ship-folder-rename-propagates`** — fat update with full
   folder entity arrives correctly.

## Cost / feasibility

### Vendoring

Add to `peru.yaml`:

- `ph-io.hoon`, `ph-test.hoon` from `tloncorp/tlon-apps:desk/lib/ph/` (or
  upstream `urbit/urbit:pkg/garden-dev` if the libraries live there)
- `verb.hoon` already vendored as part of base
- `aquarium.hoon` from `urbit/urbit:pkg/base/sur/aquarium.hoon`
- Possibly a custom `ted/ph/test.hoon` thread runner (see PR #5692)

These are pinned upstream — peru handles the sync. Maybe ~5 files total.

### Boot infrastructure

`run-aqua-tests.sh` (port from PR #5692) does:

1. Download `urbit` binary if missing
2. Boot a fake `~zod` pier with a `comet`-style brass payload
3. Apply an aqua patch (the PR ships `aqua-sur.patch`)
4. Mount the desk, install `%notes`
5. Use `click` to spawn additional virtual ships via aqua's
   `%aquarium` agent
6. Run the test thread via `|start /tests/ph/for/notes`
7. Cleanup pier on completion

Runs in seconds per setup, but each test takes seconds-to-tens-of-seconds
to execute (real ships, real time).

### Per-test development cost

Each test is similar in shape:

```hoon
++  test-cross-ship-invite-flow
  =/  m  (strand ,~)
  ^-  form:m
  ;<  ~  bind:m  (boot-ship ~zod)
  ;<  ~  bind:m  (boot-ship ~bud)
  ;<  ~  bind:m  (install-app ~zod %notes)
  ;<  ~  bind:m  (install-app ~bud %notes)
  ;<  ~  bind:m  (poke-app [~zod %notes] notes-action+!>([%create-notebook 'NB']))
  ;<  ~  bind:m  (poke-app [~zod %notes] notes-action+!>([%notebook [~zod %nb] [%visibility %public]]))
  ;<  ~  bind:m  (poke-app [~zod %notes] notes-action+!>([%notebook [~zod %nb] [%invite who=~bud]]))
  ::  expect ~bud receives invite-received on inbox stream
  ;<  kag=cage  bind:m  (wait-for-app-fact /v0/inbox/stream [~bud %notes])
  ?>  =(%json p.kag)
  ::  ... assert invite-received shape ...
  (pure:m ~)
```

Roughly 30–60 lines per test, mostly mechanical. Once the infrastructure
exists, adding a new cross-ship test is straightforward.

### CI

Urbit ships Linux binaries; aqua works on Linux containers. Adding a CI
job is doable but adds 1–2 minutes per run for boot + test. Skip if we
don't run CI yet — local-only is fine for now.

## Staged rollout

### Phase 1: Infrastructure (one-time, ~half day)

- [ ] Vendor `ph-io`, `ph-test`, `aquarium` via peru
- [ ] Port `run-aqua-tests.sh` adapted to our pier layout (sidwyn)
- [ ] Write `desk/ted/ph/test.hoon` thread runner (or vendor from PR)
- [ ] Write a "hello cross-ship" test: `~zod` pokes `~bud` with a
      no-op, expect ack. Confirms infrastructure works.
- [ ] Document `run-aqua-tests.sh` invocation in CLAUDE.md

### Phase 2: The 5–8 tests above (~few hours per test)

Implement in priority order — the regression-coverage ones first:

- [ ] `test-cross-ship-accept-invite-snapshot-seeds-visibility`
- [ ] `test-cross-ship-invite-flow`
- [ ] `test-cross-ship-visibility-toggle-propagates`
- [ ] `test-cross-ship-revision-conflict-rejects`
- [ ] `test-cross-ship-note-update-propagates`
- [ ] `test-cross-ship-leave-rejoin-fresh-snapshot`
- [ ] `test-cross-ship-subscription-kick-resub`

### Phase 3 (optional)

- [ ] CI integration on GitHub Actions
- [ ] Add to the project memory/runbook so future subagents know to
      run the aqua suite when changing cross-ship code paths

## Open questions

- **Where to stash aqua deps**: `desk/lib/ph/` (matches tlon-apps) vs
  `desk/lib/aqua/`. Probably `ph/` for parity.
- **Ship naming**: the lure PR uses `~zod`/`~bud`/`~fen`. We should
  probably mirror that — `~zod` as host, `~bud` as primary subscriber,
  `~fen` as secondary subscriber for race-condition tests.
- **Test isolation**: is each aqua run a fresh pier, or does state
  persist? Per-run fresh is safer; PR #5692's script implies fresh.
- **Speed budget**: if all 7 tests take 10s each, that's ~70s per run
  — fine for pre-commit, slow for inner-loop dev. Keep test-agent as
  the fast feedback loop; aqua is for confidence before merge.

## References

- PR #5692: <https://github.com/tloncorp/tlon-apps/pull/5692>
- Reference test: `desk/tests/ph/for/lure.hoon` in that PR (257 lines,
  3 ships, end-to-end onboarding)
- `ph-io` / `ph-test` libraries: vendored from upstream urbit base
