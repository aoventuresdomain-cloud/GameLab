# GameLab estimates

*Owned by the Head of Engineering, and the only source of dates. Nobody else quotes them. One line per open item: estimated finish (merged, and QA passed where the item needs it) and confidence. Merged and QA-passed items drop off. Refreshed whenever an item moves or an assumption breaks.*

**Confidence:** high (known work, no outside dependency) · medium (some technical unknowns) · low (depends on the CEO's hands, an outside tool or a QA round).

Last refreshed: 2026-10-21.

## Holdfast M1 → Gate 1

Done: Gate 1 passed on 2026-10-06, about 4 hours after the repository was created.

## Holdfast M2 (fun slice) → Gate 2: approved, starts when the CEO says go

Refreshed 2026-10-21, after the CEO's go and scope changes (10 Hero skills a path, Recruit skill trees, Hero-only gear, a level-5 mini-boss). Build time is active studio time from the CEO's go: building, review, CI and QA rounds. It counts one Gameplay Engineer, one UI Engineer and the part-time roles, with one open PR per builder. Calibrated on M1 (empty repository to Gate 1 in about 4 hours), so confidence is low to medium. Waits on people and outside services are listed separately and are not build time.

### Iterations (replanned 2026-10-21: lean, the CEO plays after each slice)

The CEO asked for a very lean M2: small changes shipped fast, quick fixes, and their own playtests with feedback as it develops. Outside testers are a later stage. Each slice ends in a build the CEO plays in the browser on the Mac (private itch.io draft, no steps), and the team then stops until the CEO has tested it and replied (CEO rule, 21 Oct). The days below are build days only; the CEO's testing time between slices is added by the calendar. Per slice: sanity checks, the full suite in CI's order and one production-shaped run on that commit. One full QA round, at the end only. Days are from the go (day 0 = 2026-10-21).

| Build | What the CEO can play | Items | Ready by | Confidence |
|---|---|---|---|---|
| 1 (done) | Move the Keeper with WASD, auto-fire flares, Space for Flare Barrage, keep falls = run over | HF-M2-14 first slice | 22 Oct | Done |
| 2 and 2b (done) | Three pillars, enemies fight back, light posts, knock-down, stronger monsters, Recruits that move and revive | HF-M2-14 pillars, HF-M2-15, HF-M2-17 | 22 Oct | Done |
| 3 of 7 | Gold and upgrades that save, the 5-level biome, a plain home and keep screen, Hero gets up where it fell, Mac build | KIT-06, KIT-07, HF-M2-02, HF-M2-06 (part), HF-M2-18, HF-M2-00 | AI build time: about 3 to 5 hours from 22 Oct 10:50 (kit and QA tests already merged; game PR, fixes and CI left) | Low |
| 3b of 7 | Bigger arena, Hero reaches every edge (CEO feedback) | HF-M2-19 | AI build time: about 1 hour after Build 3 | Medium |
| 3c of 7 | Levels unlock by winning the previous level; monsters go for the tower and fight the Hero only up close (CEO feedback) | HF-M2-20, HF-M2-21 | AI build time: about 3 hours after go (QA full round on core rules adds about 1 hour) | Medium |
| 4 of 7 | Hero skill paths (10 nodes each) and blessings, plus the upgrade tree changes the CEO asks for after the Advisor review (scope not yet known, so this figure may rise) | HF-M2-14 rest, HF-M2-04 | About 2 build days | Low |
| 5 of 7 | Monster variety, the elite drop, Hero gear, the level-5 mini-boss, hit feel and sound | HF-M2-16, HF-M2-07 | About 1.5 build days | Low |
| 6 of 7 | Pacing bands passed in the simulator for every pillar, style guide for approval, name check (end of the core) | HF-M2-01, HF-M2-05, HF-M2-08, HF-M2-11 | About 1 build day | Medium |
| 7 of 7 (parked) | Recruits: hiring, classes, movement, skill trees, recruitment board. Only if the CEO wants it after the core | HF-M2-03 | About 1.5 build days | Low |
| End | Full QA round on one fixed commit, then the Gate 2 brief | HF-M2-12, HF-M2-13 | About 1 build day | Low |

**Estimates on every handoff (CEO request, 2026-10-22):** each build handoff and each build start carries a rough AI build time for that build, with a confidence. AI build time is stated apart from the CEO's own test and feedback time, which is theirs to set and is not counted. Per-build figures are in the table above; build days convert at roughly 8 to 10 hours of AI build time.

**Build numbering (CEO request, 2026-10-22): the CEO gets 7 playable builds (revised 2026-10-22, core gameplay first, Recruits last), so a handoff reads "Build N of 7". A quick fix after a playtest counts inside its slice with a letter (Build 2b), not as a new number. The final full QA round and the Gate 2 brief are not numbered builds. If feedback adds a slice, the new total is stated before it starts.**

**Remaining build: about 6 to 8 build days from the 2026-10-22 go (low confidence), same total as before because Recruits only moved to the end. Earlier total: about 7 to 9 days** to Gate 2, down from 8 to 10 now that the tester prep and per-slice QA rounds are out. The builder is one Gameplay Engineer, so slices are sequential; the UI Engineer joins at iteration 3 and the Balance Analyst, Product Designer and Researcher at iteration 6. HF-M2-10 and the session log wait for the later testing stage. Fixes from the CEO's feedback are small PRs merged fast, inside the day where they are blocker or major.

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
