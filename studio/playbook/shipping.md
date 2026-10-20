# Shipping rules

*Owned by the Head of Engineering. Adopted 20 Oct 2026 from the CEO's shipping playbook, a set of lessons from a multi-engineer, AI-assisted build. These rules apply to every game and to the kit. They add to the rules in `CLAUDE.md`; where they overlap, the stricter one wins. Each rule says what to do and why.*

## Top ten

1. **Test the way it ships.** Every release candidate gets one run through the real entry points, the real screens, the real default values and a production-shaped save, from first launch to quit.
2. **Sign off the exact commit that merges.** Every QA result names a commit hash. If `main` moves under a tested build, void the run and test again on the new commit. Never combine results across hashes.
3. **Run the full suite in CI's order before sign-off**, not just the new tests. Two tests can pass alone and fail together.
4. **A finding counts only if it reproduces without test-only helpers** (fixtures, shims and mocks the shipped game never has).
5. **One owner per item and per high-risk area.** Nobody fixes someone else's item, even when they can see the fix. They log a finding instead.
6. **Push frozen heads, once.** No re-pushing while CI is queued. One combined release branch per release, frozen once.
7. **Check file overlap across open PRs before every merge**, and merge the one nearest done first.
8. **An independent reviewer (never the author) on every high-risk change.** Engineers never merge their own work.
9. **Report failures the moment they happen.** Report successes only when merged.
10. **Save work off the machine at least hourly.** Sessions and containers are disposable: only the remote repository and the shared project files survive. Push the branch; put non-repository work in the project files.

## Testing

- **Stand-ins hide crashes.** Short hand-typed names and fixtures miss what the real screen generates by default. Each release candidate gets one production-shaped run: the real build, the game's own suggested defaults, and the action a player would take from a new game to quitting. Stand-ins add to that run and never replace it. The Code Reviewer rejects a high-risk PR without it.
- **Test-only helpers lie both ways.** They invent crashes and let real failures pass. Mark production-shaped tests so helpers switch off, and require any finding to reproduce with them off.
- **Off, empty and the limits are where bugs live.** For every setting, a pack value or a save field, test off, empty, minimum, maximum and one past the limit, in both directions. A limit switched off must not mean "refuse everything", and a zero must not mean "allow everything".
- **Expected values never come from the code under test.** Compute them independently. Mutation-check critical tests: break the line, confirm the test goes red, restore it, confirm the tree is clean. Pin the call site as well as the helper, so deleting the wiring fails a test.
- **High-risk tests come first.** For anything in `kit/`, saves, Steam and the release pipeline, QA writes strict expected-failure tests from worked examples before the build starts. They become the item's Done when lines.
- **Grade every finding.** MUST FIX (a wrong result, or misleading in normal play) blocks the merge. FOLLOW-UP (a rare edge or cosmetic) is logged and doesn't block. The board's Findings table records which. Edge-case perfectionism that stalls a PR is itself a finding against the process.
- **Tests change only with the Head of Engineering's OK**, logged in the board's Test changes table. Never skip, disable or quarantine a test to go green. "Flaky" is not a root cause.

## Branches, CI and merging

- **CI is a queue.** Every re-push restarts the wait. Push once the head is frozen, and fold the catch-up merge into that last push.
- **Trial-merge before every merge.** Check every open PR against the candidate `main`. Overlap includes shared config, `project.godot` and pack schemas. Order merges when PRs open, not when they finish. A critical PR gets an explicit merge lock.
- **The merger doesn't merge their own work.** Only the Head of Engineering merges. Docs-only PRs to the board, the estimates, the slate and the plans (no code in them, `qa:sanity`) may be opened and merged by the Head of Engineering once CI is green. Every PR that changes code or content is opened by its owner and merged by the Head of Engineering.
- **No hidden scope.** Before freezing, map every commit since `main` to an item, and list anything extra under "also carries" in the PR body.
- **No half-staged commits.** Stage everything, then check the status is clean before any commit or hand-over.
- **Combining builders' work:** branch from current `main`, apply each owner's range in a fixed order, prove each owner's files match their tip, then run each owner's tests plus their neighbours'.
- **Releases with a save-format change carry a tested rollback note**: an older build must refuse a newer save safely and leave the file untouched.
- **Read CI carefully.** A run cancelled by a newer push shows as failed, so read the latest run. Refresh stale test-timing data.

## People and process

- **No "safe" or "works" without reading the consumer.** Read the code that uses a value, or run it on production-shaped data, before saying so.
- **Approval is what you can see.** Act on approval from the decision-maker themselves. A relayed "they agreed" is a prompt to check, not approval.
- **A rule change needs a full sweep.** The change item lists every screen, label, pack, test and doc that mentions the old behaviour.
- **Plan times are ceilings.** Ship the moment the checks are green, and never shorten QA to hit a time.
- **Work in progress is capped:** one open PR per builder. Going over is a conscious, time-boxed choice the Head of Engineering approves.
- **Leads propose savings unprompted**, each with the hours saved and an owner, and never by cutting quality. For example, merge QA rounds that overlap.
- **Times come from the system clock** or from file times, never from memory or hand-typing.

## Lean builds

Ponytail's rules (v5.3.2, MIT), in our words. They never override the rules above or an item's Done when lines. The aim is the least time and tokens that still meets the item.

- **Take the first option that works:** skip the unrequested feature and name it in one line; reuse existing code and helpers; use the standard library or a Godot built-in; use a dependency already installed (never a new one for a few lines); write a readable one-liner; otherwise write the minimum code that works.
- **No unrequested abstractions, options or "for later" code.**
- **Before editing, read the code and list the callers, tests and config the change reaches.** A bug fix finds the root cause once.
- **Never cut** validation, error handling, security or accessibility.
- **New logic gets one small test.**
- **Mark a shortcut** as `shortcut: <limit>, <upgrade when>`.
- **Replies are short** and end with one or two lines on what was skipped and any risk. Keep asks small and batched, and don't re-read large inputs.
- **Models:** Sonnet only, nothing on Opus (CEO, 20 Oct 2026).

## Environment

- Rebuild environments from the repository with pinned tooling.
- Give each parallel test shard its own fresh state, and re-run any error alone before calling it real.
- Kill processes by process id, never with a pattern that can match your own shell.

## Where each rule lives

| Rule | Where it's enforced |
|---|---|
| Production-shaped run, commit-hash sign-off, full suite in CI order | The Gate QA item (HF-M2-12) and every `qa:full` round |
| Expected-failure tests first | The Done when lines of HF-M2-14 and HF-M2-15 |
| Boundary cases (off, empty, limits) | Every item that adds a setting, pack field or save field |
| MUST FIX or FOLLOW-UP | The board's Findings table |
| Rollback note | KIT-07 and any later save-format change |
| One owner, overlap check, independent reviewer | `CLAUDE.md` and the Head of Engineering's merge checklist |
