# Studio rules for Claude

Read `README.md` for the layout. The full team structure and rules live in the GameLab project instructions; these are the ones that matter in the repository.

- **One board.** `studio/board.md` lists every item for every game and the kit. Each item has one owner and 2-5 checkable Done when lines. Engineering reviews against them; QA tests against them. Only the Head of Engineering edits item status and merges.
- **Slate.** `studio/slate.md` is owned by the Chief of Staff.
- **Kit boundary.** Nothing game-specific in `kit/`. Until game two starts, build only what the current game needs. Kit changes need Head of Engineering review, a full QA round and green tests for every active game.
- **Packs are data only**, never code.
- **QA by risk.** Sanity checks on every change (red blocks merge). Interface-only changes add a walk of the changed screens. A full end-to-end round when core logic changes: anything in `kit/`, a game's save data and offline earnings, Steam integration, the release pipeline. Label each PR `qa:sanity`, `qa:screens` or `qa:full`; unlabelled means full.
- **The repository is public (CEO decision, 6 Oct 2026).** Commit nothing commercially sensitive: no prices, revenue or sales projections, budgets, wishlist or review targets, or stop-rule thresholds. Plans in the repository are build excerpts; the full plans stay in the GameLab project files. CI fails on currency amounts in £ or €.
- **Secrets** only in CI secrets. Never commit keys, never ask anyone to paste one in chat.
- **Public steps need the CEO's go-ahead:** any public release, prices, paid sign-ups, paid marketing or budgets. Hands-on needs go through the Setup Desk.
- British English in docs and UI text.
