# GameLab estimates

*Owned by the Head of Engineering, and the only source of dates. Nobody else quotes them. One line per open item: estimated finish (merged, and QA passed where the item needs it) and confidence. Merged and QA-passed items drop off. Refreshed whenever an item moves or an assumption breaks.*

**Confidence:** high (known work, no outside dependency) · medium (some technical unknowns) · low (depends on the CEO's hands, an outside tool or a QA round).

Last refreshed: 2026-10-06.

## Holdfast M1 → Gate 1

Done: Gate 1 passed on 2026-10-06, about 4 hours after the repository was created.

## Holdfast M2 (fun slice) → Gate 2: approved, starts when the CEO says go

Refreshed 2026-10-20. Build time is active studio time from the CEO's go: building, review, CI and QA rounds. It counts one Gameplay Engineer, one UI Engineer and the part-time roles, with one open PR per builder. Calibrated on M1 (empty repository to Gate 1 in about 4 hours), so confidence is low to medium. Waits on people and outside services are listed separately and are not build time.

### Build time, in order (lanes run in parallel)

| Lane | Items | Owner | Done by (build) | Confidence | Main risk |
|---|---|---|---|---|---|
| Foundations | KIT-08, KIT-06, KIT-07, HF-M2-00 | Gameplay Engineer | +1 day | Medium | Windows hash drift; the unsigned Mac build with GodotSteam |
| Rules | HF-M2-14 Your Hero, HF-M2-15 Enemies fight back (QA's expected-failure tests first) | Gameplay Engineer | +2 to 3 days | Medium | Keeping the Hero's inputs deterministic for the simulator |
| Content | HF-M2-02 progression, HF-M2-03 Recruits, HF-M2-04 blessings, HF-M2-05 simulator | Gameplay Engineer | +4 to 5 days | Low | Pacing rework rounds |
| Screens | HF-M2-06 home and keep screens, HF-M2-07 feel (start on stub data) | UI Engineer | +4 days | Medium | Reworks when Hero and Recruit rules settle |
| Bands and style | HF-M2-01 pacing bands, HF-M2-08 style guide | Balance Analyst, Product Designer | +1 to 2 days | Medium | Bands need real numbers from HF-M2-02 to settle |
| Research | HF-M2-11 name check | Researcher | +1 day | High | None |
| Hand-over | HF-M2-09 playtest build, HF-M2-12 Gate 2 QA round | Gameplay Engineer, Head of QA | +6 to 7 days | Low | Fix rounds from the QA round |

**Build total: about 6 to 7 days** to a tested playtest build. That is longer than the earlier 4 to 5 days, because the Hero and Recruit rules are sequential on one Gameplay Engineer and the shipping rules add a QA round and a production-shaped run.

### Waits (not build time; the calendar)

| Wait | Who | Starts | Typical length | Confidence |
|---|---|---|---|---|
| Mac steps for HF-M2-00 (right-click Open, run the Steam check) | CEO, via the Setup Desk | Day 1 | Same day | Medium |
| Approve the tester recruitment post | CEO | Day 0 | Same day | Medium |
| Recruit 5-10 outside testers, then sessions and the report (HF-M2-10) | Player Researcher, testers | Day 0, overlapping the build | 1 to 2 weeks | Low |
| Play the M2 build on the Mac | CEO | After HF-M2-12 | Their choice | n/a |
| Approve the style, then decide Gate 2 | CEO | After the tester report | Their choice | n/a |

**Critical path: the testers, not the build.** The Gate 2 brief (HF-M2-13) follows the tester report, so expect it about 1 to 2 weeks after the build is done, or 2 to 3 weeks from go (low confidence).

## Holdfast M2 to M7: rough build time (asked by the CEO, 2026-10-06)

Active build time on the same basis as above, recalibrated against M1. Each milestone starts when the one before passes its gate. Nothing past M2 has board items yet, so confidence is low throughout. This section is replaced with item-level lines as each milestone is planned.

| Milestone | Build time | Confidence | Main risk |
|---|---|---|---|
| M2 Fun slice | 4 to 5 days | Low | Pacing rework rounds |
| M3 Designer pipeline | 1 to 2 days | Low | The design agent producing packs that pass the simulator first time |
| M4 Steam page and demo | 1 to 2 days, alongside M3 | Low | Store art and trailer quality |
| M5 Full game | 1 to 2 weeks | Low | Content volume and the CEO approving packs |
| M6 Launch prep | 2 to 3 days | Medium | Fix rounds from the release QA round |
| M7 Steam launch | About 1 day | Medium | Release build and store checks |

**Total build:** about 3 to 4 weeks. This is not a calendar date. The calendar is set by waits on people and outside services: tester sessions, the CEO's playtests and pack approvals, Valve review, and the plan's Gate 3 demo test and Steam Next Fest dates.
