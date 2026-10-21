# M2 expected-failure tests (Head of QA)

Strict tests written before the build, for KIT-07, HF-M2-14, HF-M2-15 and HF-M2-16. Expected values are worked by hand in each test and never read back from the code. They are those items' Done when evidence.

## How "pending" works

Each test asks for a seam: the script the build must provide. While the seam is not built, its id is listed in the project's `qa_pending.json` and the tests print `PENDING` and pass, so CI stays green.

- Seam present and id still listed: **fails**. The build's PR must remove the id (the tests are strict from then on).
- Seam missing and id not listed: **fails**. It was renamed, moved or never built.

So a test cannot sit pending behind a finished build. Removing an id is the build PR's job; adding one is a QA decision.

| Id | Item | Seam the build provides | Pending file |
|---|---|---|---|
| `save_service` | KIT-07 | `kit/services/save/save_service.gd` (`SaveService`) | `kit/tests/qa_pending.json` |
| `save_wiring` | KIT-07 | a script under `games/holdfast/scripts` that uses `SaveService` | `games/holdfast/tests/qa_pending.json` |
| `hero_knockdown` | HF-M2-14 | `scripts/rules/hero_knockdown.gd` | same |
| `hero_paths` | HF-M2-14 | `scripts/rules/hero_paths.gd` | same |
| `enemy_targeting`, `unit_health`, `lit_area` | HF-M2-15 | `scripts/rules/enemy_targeting.gd`, `unit_health.gd`, `lit_area.gd` | same |
| `hero_gear`, `boss_rules` | HF-M2-16 | `scripts/rules/hero_gear.gd`, `boss_rules.gd` | same |

Each test file opens with the exact function signatures and the rules it pins. Names are QA's: if one has to change, ask QA before the build starts, never after.

## Rules QA has read from the board (Head of Engineering to rule on any that is wrong)

- Save: corrupt save falls back to the previous good one and the player is told; a newer save is refused untouched by an older build; a missing migration step refuses rather than guesses; unsavable values (NaN, infinity, objects) are refused and never damage the existing save.
- Knock-down: health at or below zero knocks down once; hits while down do nothing; a delay of zero is honoured; the count survives get-ups; the last delay holds for later knock-downs.
- Skill paths: 10 nodes per path (3 tiers of 3, one capstone); a tier opens on enough nodes of the tier below **in the same path**; a threshold of 0 opens only its own tier; respec returns every point, costs gold, and is free when nothing is owned.
- Enemies: nearest wins; an exact tie follows `tie_order`, then the smaller id; no candidates gives no target; a lit area gives its bonus once, on the edge included.
- Gear and boss: Recruits have no slots; normal enemies never drop gear; elites drop only on listed levels and only below the chance; the boss drops on its level; hits without the path ability do nothing to the boss.

## Proof the tests are satisfiable and strict

Run on a scratch copy with throwaway reference code (not committed): all tests passed strictly with the ids removed. Eighteen deliberate mutations of the reference (off-by-one at each boundary, a missing path check, a skipped refund, JSON instead of exact serialisation, and so on) were each caught, apart from two that turned out to change nothing observable.

## Handing over

When the Gameplay Engineer builds an item, their PR removes that item's ids from `qa_pending.json`, and the tests become the item's evidence. The wiring pins (`*_actually_use_*`) stop an engine that is built but never called from passing.
