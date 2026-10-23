# Build 7 resume note (parked)

Status: parked by the CEO (2026-10-22 23:02) until they have tested 4b, Build 5 and Build 6 and confirmed. Nothing of Build 7 is built or pushed.

Direction (CEO, 2026-10-22 23:10): focus on the Flare Archer and getting the mechanics complete. Balancing the other pillars and recalibrating level difficulty is future work (HF-M2-28). When Build 7 is proposed again it is mechanics-first and Archer-only, not a cross-pillar balance pass.

## What the Gameplay Engineer learned (from the Build 6 work)

- Pooled win-rate bands are steep around the target, so a small multiplier change moves a level a lot.
- The bots are deterministic, so nearby wave multipliers show plus or minus 10 points of jitter. Judge a band over several multipliers, not one.
- Wave scaling must keep waves strictly increasing (the Build 4 wave-by-wave test enforces it).
- `kit_gold` in `balance_check` was lowered in #82 (Old Pier and Gull Rock) so a loss stays possible. It needs recalibrating together with the levels (HF-M2-28, F-051).
- A test buff of Dusk Mage and Tideblade attack damage closed most of the per-pillar gap, but it was not applied: Hero buffs were not decided by the CEO. The Advisor's view is in the board's Advisor views table (recommends buffing the weak pillars, keeping the Flare Archer as is).
- Flare Archer first-time win rates after #82 (average / poor bot, 40 seeds): L1 100/100, L2 100/92, L3 95/92, L4 90/55, L5 87/72.

## Open items to pick up

- HF-M2-28 (backlog) holds the balance work and the related findings: F-043, F-044, F-045, F-049, F-051.
- HF-M2-11 (name check) needs a Researcher thread from the Chief of Staff.
- Data-integrity follow-ups: F-046 and F-050.
