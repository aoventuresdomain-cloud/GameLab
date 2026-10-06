# GameLab estimates

*Owned by the Head of Engineering, and the only source of dates. Nobody else quotes them. One line per open item: estimated finish (merged, and QA passed where the item needs it) and confidence. Merged and QA-passed items drop off. Refreshed whenever an item moves or an assumption breaks.*

**Confidence:** high (known work, no outside dependency) · medium (some technical unknowns) · low (depends on the CEO's hands, an outside tool or a QA round).

Last refreshed: 2026-10-06.

## Holdfast M1 → Gate 1

| Item | Owner | Est. finish | Confidence | Main risk |
|---|---|---|---|---|
| KIT-01 Kit addon linked into Holdfast | Gameplay Engineer | 2026-10-07 | High | Link method on a Windows checkout |
| KIT-05 CI tests and exports | Gameplay Engineer | 2026-10-08 | Medium | Godot export templates and web export settings in CI |
| KIT-02 Shared simulation engine | Gameplay Engineer | 2026-10-08 | Medium | Determinism across timestep and RNG |
| KIT-03 Pack format v0 and loader | Gameplay Engineer | 2026-10-08 | Medium | Rejecting non-data content cleanly |
| HF-M1-04 Run HUD and flow screens (QA) | UI Engineer | 2026-10-09 | Medium | Needs KIT-05 builds for the Windows and browser check |
| KIT-04 Steam service | Gameplay Engineer | 2026-10-09 | Low | GodotSteam build for Godot 4.6 |
| HF-M1-01 Combat rules on the shared engine | Gameplay Engineer | 2026-10-09 | Medium | Headless and build results matching exactly |
| HF-M1-02 Ten hours headless under a minute | Gameplay Engineer | 2026-10-10 | Medium | Speed of the rules loop |
| HF-M1-03 One playable level | Gameplay Engineer | 2026-10-10 | Medium | Web export performance |
| HF-M1-06 macOS export check | Gameplay Engineer | 2026-10-10 | Medium | Export templates on a Linux runner |
| HF-M1-05 Test Steam achievement | Gameplay Engineer | 2026-10-13 | Low | Needs the CEO's Windows PC with Steam (Setup Desk) |
| HF-M1-07 Gate 1 full QA round | Head of QA and Validation | 2026-10-14 | Low | Fix rounds; never shortened to hit this date |
| HF-M1-08 Gate 1 brief | Head of Engineering | 2026-10-15 | Low | Follows the QA round |

**Gate 1 ready for the CEO:** 2026-10-15, low confidence. The two things most likely to move it are the Steam achievement check on the CEO's PC and the number of QA fix rounds.
