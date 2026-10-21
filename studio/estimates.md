# GameLab estimates

*Owned by the Head of Engineering, and the only source of dates. Nobody else quotes them. One line per open item: estimated finish (merged, and QA passed where the item needs it) and confidence. Merged and QA-passed items drop off. Refreshed whenever an item moves or an assumption breaks.*

**Confidence:** high (known work, no outside dependency) · medium (some technical unknowns) · low (depends on the CEO's hands, an outside tool or a QA round).

Last refreshed: 2026-10-21.

## Holdfast M1 → Gate 1

Done: Gate 1 passed on 2026-10-06, about 4 hours after the repository was created.

## Holdfast M2 (fun slice) → Gate 2: approved, starts when the CEO says go

Refreshed 2026-10-21, after the CEO's go and scope changes (10 Hero skills a path, Recruit skill trees, Hero-only gear, a level-5 mini-boss). Build time is active studio time from the CEO's go: building, review, CI and QA rounds. It counts one Gameplay Engineer, one UI Engineer and the part-time roles, with one open PR per builder. Calibrated on M1 (empty repository to Gate 1 in about 4 hours), so confidence is low to medium. Waits on people and outside services are listed separately and are not build time.

### Iterations (replanned 2026-10-21: lean, the CEO plays after each slice)

The CEO asked for a very lean M2: small changes shipped fast, quick fixes, and their own playtests with feedback as it develops. Outside testers are a later stage. Each slice ends in a build the CEO plays in the browser on the Mac (private itch.io draft, no steps). Per slice: sanity checks, the full suite in CI's order and one production-shaped run on that commit. One full QA round, at the end only. Days are from the go (day 0 = 2026-10-21).

| Iteration | What the CEO can play | Items | Ready by | Confidence |
|---|---|---|---|---|
| 1 | Move the Keeper with WASD, lantern burns fog creatures, press Space for the path ability, keep falls = run over | HF-M2-14 first slice | Day 1 (22 Oct) | Medium |
| 2 | Enemies fight back, light posts, knock-down and respawn, a minimal home screen | HF-M2-15, KIT-08 (CI only) | Day 2 to 3 | Medium |
| 3 | Gold and upgrades that save, the recruitment board and a 2-slot squad, Mac build | KIT-06, KIT-07, HF-M2-02, HF-M2-03, HF-M2-00 | Day 4 to 5 | Low |
| 4 | Hero skill paths (10 nodes each), Recruit skill trees, blessings | HF-M2-14 rest, HF-M2-03 trees, HF-M2-04 | Day 6 to 7 | Low |
| 5 | Hero gear, the level-2 or 3 elite drop, the level-5 mini-boss, feel and sound, home and keep polish | HF-M2-16, HF-M2-06, HF-M2-07 | Day 7 to 8 | Low |
| 6 | Pacing bands pass in the simulator, style guide for approval, name check | HF-M2-01, HF-M2-05, HF-M2-08, HF-M2-11 | Day 8 | Medium |
| End | Full QA round on one fixed commit, then the Gate 2 brief | HF-M2-12, HF-M2-13 | Day 8 to 9 | Low |

**Build total: about 7 to 9 days** to Gate 2, down from 8 to 10 now that the tester prep and per-slice QA rounds are out. The builder is one Gameplay Engineer, so slices are sequential; the UI Engineer joins at iteration 3 and the Balance Analyst, Product Designer and Researcher at iteration 6. HF-M2-10 and the session log wait for the later testing stage. Fixes from the CEO's feedback are small PRs merged fast, inside the day where they are blocker or major.

### Waits (the calendar, not build time)

| Wait | Who | Typical length | Confidence |
|---|---|---|---|
| About 10 minutes on the Mac for HF-M2-00 (right-click Open, run the Steam check), at iteration 3 | CEO, via the Setup Desk | Same day | Medium |
| Play each build and send feedback | CEO | Their choice; feedback after each slice keeps the next slice on track | n/a |
| Approve the style, then decide Gate 2 | CEO | Their choice | n/a |

**Critical path: the build itself, plus the CEO's feedback loop.** The outside-tester wait is gone from M2. Gate 2 can be decided about 1 day after the final build, subject to the CEO's own playtest time.

## Holdfast M2 to M7: rough build time (asked by the CEO, 2026-10-06)

Active build time on the same basis as above, recalibrated against M1. Each milestone starts when the one before passes its gate. Nothing past M2 has board items yet, so confidence is low throughout. This section is replaced with item-level lines as each milestone is planned.

| Milestone | Build time | Confidence | Main risk |
|---|---|---|---|
| M2 Fun slice | 7 to 9 days (see iterations above) | Medium | Pacing rework rounds |
| M3 Designer pipeline | 1 to 2 days | Low | The design agent producing packs that pass the simulator first time |
| M4 Steam page and demo | 1 to 2 days, alongside M3 | Low | Store art and trailer quality |
| M5 Full game | 1 to 2 weeks | Low | Content volume and the CEO approving packs |
| M6 Launch prep | 2 to 3 days | Medium | Fix rounds from the release QA round |
| M7 Steam launch | About 1 day | Medium | Release build and store checks |

**Total build:** about 3 to 4 weeks (M2 at 7 to 9 days sits in the middle). This is not a calendar date. The calendar is set by waits on people and outside services: tester sessions, the CEO's playtests and pack approvals, Valve review, and the plan's Gate 3 demo test and Steam Next Fest dates.
