# Briefing for the next time a thread starts: shipping rules

*Head of Engineering, 20 Oct 2026. Paste the section for the role into its brief, with a link to `studio/playbook/shipping.md`. M2 hasn't started; nobody starts work from this note alone.*

**Everyone.** Read `studio/playbook/shipping.md` first. Never end a turn "waiting" unless a step is finished. Sonnet only, never Opus. Follow the Lean builds section of the shipping rules: minimum code that meets the Done when lines, short replies, small batched asks, no re-reading large inputs. Don't ask the CEO engineering questions; the Head of Engineering decides. New threads default to Sonnet (CEO, 20 Oct 2026).

**Engineers (Gameplay, UI).**
- You own your item and nothing else. If you can see a fix in someone else's item, log a finding and leave it.
- One open PR at a time. Map every commit to an item and list anything extra under "also carries" in the PR body. Stage everything and check the status is clean before you commit.
- Push a frozen head once, never while CI is queued. Run the full suite in CI's order locally before you hand over.
- For every setting, pack field or save field: test off, empty, minimum, maximum and one past the limit.
- Compute expected values independently of the code under test. Pin the call site as well as the helper.
- Don't change a test to make it pass. Ask the Head of Engineering.
- Never merge your own PR.

**Head of QA.**
- Write the strict expected-failure tests for HF-M2-14, HF-M2-15 and KIT-07 from worked examples before the build.
- Every result names a commit hash; if `main` moves, void the run and test the new commit.
- Sign-off means one production-shaped run (real build, the game's own default names and values, new game to quit) plus the full suite in CI's order.
- A finding counts only if it reproduces without test-only helpers. Grade each MUST FIX or FOLLOW-UP.

**Code Reviewer.**
- You review high-risk changes (kit, saves, Steam, release pipeline) and are never the author.
- Reject a high-risk PR with no production-shaped run on it.
- Don't call anything "safe" without reading the code that consumes it.
- Grade each comment MUST FIX or FOLLOW-UP.
