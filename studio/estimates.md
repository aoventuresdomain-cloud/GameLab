# GameLab estimates

*Owned by the Head of Engineering, and the only source of dates. Nobody else quotes them. One line per open item: estimated finish (merged, and QA passed where the item needs it) and confidence. Merged and QA-passed items drop off. Refreshed whenever an item moves or an assumption breaks.*

**Confidence:** high (known work, no outside dependency) · medium (some technical unknowns) · low (depends on the CEO's hands, an outside tool or a QA round).

Last refreshed: 2026-10-06.

## Holdfast M1 → Gate 1

Done: Gate 1 passed on 2026-10-06, about 4 hours after the repository was created.

## Holdfast M2 (fun slice) → Gate 2: approved, starts when the CEO says go

**Recalibrated 2026-10-06.** The earlier figures were in weeks, as if for a human team. M1 went from an empty repository to Gate 1 in about 4 hours of studio time, review and QA rounds included. These figures are scaled to that. They count active build time: building, review, CI and QA rounds, and simulator-driven tuning. They leave out time waiting on people: outside testers, the CEO's playtests and approvals, and Valve review. Low confidence, because M1 is the only calibration point so far. One hero you control, plus recruits (CEO, 2026-10-06).

| Stage | Owner | Est. finish (build time from go) | Confidence | Main risk |
|---|---|---|---|---|
| Windows determinism and screenshots, Mac build and live Steam check, pacing bands, pack v1, save service, style guide | Gameplay Engineer, Balance Analyst, Product Designer | +1 day | Medium | Windows hash drift; the unsigned Mac build with GodotSteam; the Steam check waits on the CEO's Mac |
| Core of a run: your hero, enemies fight back, parity holds | Gameplay Engineer | +2 days | Medium | Keeping player input deterministic for the simulator |
| Slice content (biome, 5 levels, recruits, upgrade tree, blessings), home and keep screens, feel, simulator gating | Gameplay Engineer, UI Engineer | +3 to 4 days | Low | Pacing rework rounds |
| Gate 2 QA round, then the brief once the tester report is in | Head of QA and Validation, Head of Engineering | +4 to 5 days, plus the tester sessions | Low | Fix rounds; tester recruiting starts at go so it overlaps the build |

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
