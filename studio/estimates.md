# GameLab estimates

*Owned by the Head of Engineering, and the only source of dates. Nobody else quotes them. One line per open item: estimated finish (merged, and QA passed where the item needs it) and confidence. Merged and QA-passed items drop off. Refreshed whenever an item moves or an assumption breaks.*

**Confidence:** high (known work, no outside dependency) · medium (some technical unknowns) · low (depends on the CEO's hands, an outside tool or a QA round).

Last refreshed: 2026-10-23 (tree and star logic added; offline earnings removed by the CEO, it was never a line here).

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
| 3 of 7 | Gold and upgrades that save, the 5-level biome, a plain home and keep screen, Hero gets up where it fell, Mac build | KIT-06, KIT-07, HF-M2-02, HF-M2-06 (part), HF-M2-18, HF-M2-00 | AI build time: about 3 to 5 hours from 22 Oct 10:50 (kit and QA tests already merged; game PR, fixes and CI left) | Low. Actual: all eight items merged in about 4 hours of wall-clock from the release of the build, of which about 2 hours were lost between steps waiting on a hand-off, so roughly 2 hours of build and QA, well under the low end |
| 3b of 7 | Bigger arena, Hero reaches every edge (CEO feedback) | HF-M2-19 | AI build time: about 1 hour after Build 3 | Medium |
| 3c of 7 | Levels unlock by winning the previous level; monsters go for the tower and fight the Hero only up close (CEO feedback) | HF-M2-20, HF-M2-21 | AI build time: about 3 hours after go (QA full round on core rules adds about 1 hour) | Medium |
| 4 of 8 | Winnable early levels and a 1 s pause with a "Wave N" banner between waves (CEO feedback; tower revive dropped) | HF-M2-22, HF-M2-23 | Done, handed over 2026-10-22 | Done |
| 4b of 8 | CEO feedback after Build 4: waves wait for the last monsters (if the Advisor and the CEO choose that), a longer Flare Barrage that fires rapidly for a few seconds, buttons after a win to go to the next level or the upgrade screen. Held until the Advisor's view and the CEO's go | to be itemised | AI build time: about 45 to 60 minutes including QA | Medium |
| 5 of 8 | Flare Archer and Archer Post tree: sections, a Sniper/Volley fork, site planning on levels 1 and 2 with enemies from more than one direction (CEO, 2026-10-22 19:15). Reuses the held 17-node work's save migration, respec and next-unlock display | HF-M2-26, HF-M2-14 rest (Flare Archer), HF-M2-04 if kept | AI build time: about 3 to 4 hours, plus about 45 minutes QA (recalibrated 2026-10-22, see below) | Medium to low |
| 6 of 8 | Monster variety, the elite drop, Hero gear, the level-5 mini-boss, new monster types, the Hero gear (hit feel and sound moved to after Build 8, CEO 2026-10-22) | HF-M2-16 | About 4 to 5 hours | Low |
| Rework A (slot to be decided by the CEO) | Main menu, journey map, Plan page with Archer Post cards dragged into slots, Auto-place and Quick start, result screen links, Hero figure and page | HF-M2-29 | AI build time: about 2.5 to 4 hours in two PRs (includes the Hero page), plus about 45 minutes of QA per PR | Medium to low |
| Rework B | The skill tree as one zoomable web with jump tabs (Hero, Archer Post, Keep) | HF-M2-30 | AI build time: about 2 to 3 hours, plus about 45 minutes of QA | Low |
| Tree 1 (CEO go 2026-10-23 09:27) | Stars, empty castle, Level 0 stub, guided first buys, Plan ring of 8 spots, old-save refund | HF-M2-32 | AI build time: about 1.5 to 3 hours including QA. Worst case 5, upper bound 6 | Medium to low |
| Tree 2 | One connected tree with gold and star nodes, castle arm, respec fee, tree drag-pan and zoom fix | HF-M2-33 | About 2.25 to 4 hours including QA. Worst case 7, upper bound 8 | Low |
| Tree 3 | Six Hero and tower links (Lit Post, Pillar Echo, Rally, Last Light, Watchtower, Crossfire) | HF-M2-34 | About 1.5 to 3 hours including QA. Worst case 5, upper bound 6 | Low |
| Tree 4 (built last) | Retune levels 1 to 5 for an empty-castle start with gear and the Mage Post, bots that place posts by stars | HF-M2-35 | About 2 to 4 hours including QA. Worst case 8, upper bound 10 (retune rounds) | Low |
| Tree 5 (CEO go 2026-10-23 10:12) | Hero gear: five slots, inventory, stat breakdown | HF-M2-36 | About 2 to 4 hours including QA. Worst case 6, upper bound 8 | Low to medium |
| Tree 6 | Mage Post and the first Tower Gate (Mender and Frost not offered yet) | HF-M2-37 | About 3 to 5 hours including QA. Worst case 8, upper bound 10 | Low |
| Feedback slice (CEO feedback and research, 2026-10-24) | Compulsory guide and zoomed-out tree; any-N-spots placement with the "+ Tower" shortcut; interface tidy, Refund and Hero page; skill detail card; the first minutes (early fight, two-tap guide, stars line); always something to buy and a certain first gear drop | HF-M2-38 to HF-M2-45 | About 6.5 to 12.5 hours of AI build time including QA for what is left (38 fix 0.5, 39 1 to 2, 40 1.5 to 3, 43 1.5 to 3, 44 1 to 2, 45 1 to 2). Worst case 20, upper bound 24 (the CEO may change the design after the first look) | Low |
| Feedback fixes round 1 (CEO test of the feedback build, 2026-10-24) | First guide text, no tower in Level 0, card closes on buy, no auto-start, recruits parked, gear to inventory, Mage text layout; then a QA dry run | HF-M2-46 to HF-M2-52 | About 2 to 4 hours of AI build time including QA and the dry run. Worst case 8, upper bound 10 (the recruit cause is unknown) | Medium-low |
| Plan from the journey map; radial skill tree (CEO asks, 2026-10-24) | HF-M2-53 Plan entry on the map; HF-M2-54 radial mockup and Advisor critique; HF-M2-55 the build | HF-M2-53 to HF-M2-55 | 53: about 0.5 to 1 hour. 54: about 1 to 2 hours (Designer, then Advisor 0.5). 55: about 3 to 6 hours of AI build time including QA, worst case 10 (it re-lays about 100 nodes and the pan and zoom tests), upper bound 12. Actual: 53 under 1 hour; 55 about 1 hour from the go to QA clear (PR up in 32 minutes, engineer's own guess 2 to 3 hours) | 53 medium; 55 low |
| M2b (was 7 of 8; CEO 2026-10-23) | Overall pacing, stat tidy-up and balance of every pillar and level, after all mechanics are settled; style guide and name check ride along. Final art is the last step after that | HF-M2-01, HF-M2-05, HF-M2-28, HF-M2-08, HF-M2-11 | About 5 to 9 hours including QA, worst case 14 | Low |
| 8 of 8 (parked) | Recruits: hiring, classes, movement, skill trees, recruitment board. Only if the CEO wants it after the core | HF-M2-03 | About 4 to 5 hours | Low |
| End | Full QA round on one fixed commit, then the Gate 2 brief | HF-M2-12, HF-M2-13 | About 2 to 3 hours | Low |

**The run 4b + 5 + 6 (CEO go, 2026-10-22 19:35): about 9 to 11 hours of AI build time (4b about 1 hour, Build 5 about 4, Build 6 about 4 to 5) plus about 2 hours of QA across the three, low to medium confidence; one handoff at the end. Your test time is not counted.**

**Recalibration (CEO feedback, 2026-10-22 19:27): the figures were about 3 to 4 times too high. Build 4 was quoted at about 2 build days with the tree and 4 hours for its non-tree part; the non-tree part (wave pause, easing, bots, QA, merges) took about 2 hours from go to handover, and the 17-node tree about 45 minutes to build. From now on one hour of quoted AI build time is based on this pace: a slice of this size is 1 to 4 hours including QA, and I convert to days only for the whole plan. Builds 6 to the end are cut by the same factor; confidence stays low for them.**

**Estimates on every handoff (CEO request, 2026-10-22):** each build handoff and each build start carries a rough AI build time for that build, with a confidence. AI build time is stated apart from the CEO's own test and feedback time, which is theirs to set and is not counted. Per-build figures are in the table above; build days convert at roughly 8 to 10 hours of AI build time.

**Build numbering (CEO request, 2026-10-22): the CEO gets 8 playable builds (revised 2026-10-22 19:15: the tree became its own slice, core gameplay first, Recruits last), so a handoff reads "Build N of 8". A quick fix after a playtest counts inside its slice with a letter (Build 2b), not as a new number. The final full QA round and the Gate 2 brief are not numbered builds. If feedback adds a slice, the new total is stated before it starts.**

**Remaining build: about 12 to 18 hours of AI build time to Gate 2 (low confidence), recalibrated 2026-10-22 from Build 4's actual pace. The calendar is set by the CEO's test and decision time, which is not counted.** The builder is one Gameplay Engineer, so slices are sequential.

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
