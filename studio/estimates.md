# GameLab estimates

*Owned by the Head of Engineering, and the only source of dates. Nobody else quotes them. One line per open item: estimated finish (merged, and QA passed where the item needs it) and confidence. Merged and QA-passed items drop off. Refreshed whenever an item moves or an assumption breaks.*

**Confidence:** high (known work, no outside dependency) · medium (some technical unknowns) · low (depends on the CEO's hands, an outside tool or a QA round).

Last refreshed: 2026-10-06.

## Holdfast M1 → Gate 1

| Item | Owner | Est. finish | Confidence | Main risk |
|---|---|---|---|---|
| HF-M1-05 Test Steam achievement | Gameplay Engineer | The CEO's Windows session, then same day | Low | Waits only on the CEO's PC with Steam (Setup Desk checklist sent 2026-10-06); CI already proves GodotSteam loads |
| HF-M1-07 Gate 1 full QA round | Head of QA and Validation | The CEO's Windows session, then same day | Medium | Round 1 found no blockers or majors; only the Windows cases remain |
| HF-M1-08 Gate 1 brief | Head of Engineering | Sent 2026-10-06 | High | Approval waits on the CEO |

Merged and waiting on the Gate 1 full round (finish with HF-M1-07): KIT-01, KIT-02, KIT-03, KIT-04, KIT-05, HF-M1-01, HF-M1-02, HF-M1-03, HF-M1-04, HF-M1-06.

**Gate 1 ready for the CEO:** now, subject to the CEO's own Windows session. Nothing else is outstanding.

## Holdfast M2 (fun slice) → Gate 2: proposed, starts only when the CEO approves Gate 1 and the M2 plan

Weeks are counted from that approval. Low confidence until the tester route is approved and the pacing bands exist.

| Stage | Owner | Est. finish | Confidence | Main risk |
|---|---|---|---|---|
| Windows determinism, pacing bands, pack v1, save service, style guide | Gameplay Engineer, Balance Analyst, Product Designer | +1 week | Medium | Windows hash drift found by the new check |
| Slice content (biome, 5 levels, 4 staff, upgrade tree, blessings), screens, feel, simulator gating | Gameplay Engineer, UI Engineer | +3 to 4 weeks | Low | Pacing rework rounds |
| Tester sessions and report (5-10 outside testers) | Player Researcher | +4 to 5 weeks | Low | Recruiting; starts at approval so it overlaps the build |
| Gate 2 QA round and brief | Head of QA and Validation, Head of Engineering | +5 to 6 weeks | Low | Fix rounds |
