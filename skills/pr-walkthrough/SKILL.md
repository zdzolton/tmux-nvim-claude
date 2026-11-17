---
name: pr-walkthrough
description: Walk through a diff one hunk at a time, with next/back/skip/jump/stop controls. Use after the user accepts a walkthrough offer, when the user asks to walk through or hunk-review a PR (their own or someone else's), or when the user asks to review their local diff before pushing a draft.
---

# PR walkthrough

Walk through a diff one hunk at a time. Never start unprompted. The user must ask for it or accept your offer.

## Pick the source

**Own work, before push (no PR yet):**
- Use the current worktree. Do not create a new one.
- Diff against the merge base with `main`: `git diff $(git merge-base origin/main HEAD)`.

**Own PR, already open:**
- Use the PR branch worktree if it exists. Get the diff with `gh pr diff <n>`.

**Someone else's PR:**
- Do not touch the current working directory or branch.
- Create a separate git worktree: `gh pr checkout` inside a fresh worktree, or `git worktree add` and fetch the PR ref.
- When the walkthrough ends, remove the review worktree with `git worktree remove <path>` from the main repo. Delete the local branch with `git branch -D` only after `gh pr list --state all --head <branch>` shows a merged PR. Do not delete remote branches.

## Mechanics

- One **hunk** per step. State the control words first: `next` to advance, `back` to revisit, `skip` to pass the current hunk, `jump to <file>` to move around, `stop` or `done` to end early.
- After each hunk, stop and wait. Advance only on `next` or another control word. Never chain through several hunks.
- **Never print code listings.** Give only the file path and line numbers, plus identifiers such as function, class, or method names. The user opens the file in an editor split. Describe the change in prose, not as a diff. This rule applies only inside a walkthrough.
- **Step header: path last, nothing after it.** Use `Step N/M — lines A-B in <path>`. For a one-line hunk, use `line A`. No comma, period, bold marker, backtick, or other character may follow the path. Do not bold the header.
  - Wrong: `Step 2/10 — service/src/main/java/com/example/guice/OrderServiceModule.java, lines 100-131`
  - Right: `Step 2/10 — lines 100-131 in guice/OrderServiceModule.java`
- **Header range:** A is the first changed line and B is the last changed line in the new file. Do not count the diff context lines.
- **Changed line:** when a hunk has more than one separate block of changes, add this line under the header: `Changed: 182-184, 205-206, 228-231 (9 added, 2 removed)`. List each changed block in the new file. Give the counts of added and removed lines. Skip this line when the hunk is one contiguous block.
  - Pure deletion: `Changed: removed old lines 40-52 (now between 39 and 40)`. In the header, use the line after the gap.
  - Mixed hunk: list the new-file ranges. Add `removed old lines X-Y` as a separate item.
  - New file: use `lines 1-N (new file)` in the header. Skip the `Changed:` line.
  - Take all numbers from the diff hunk headers. Do not guess.
- **Open the hunk in Neovim.** Before you write each step, run `nvim-open <abs-path> <first> <last>`. Use the full absolute path of the file in the worktree. Put the path in single quotes, because file names in a reviewed PR are not trusted. Use the header range for `<first>` and `<last>`. For a pure deletion, use the nearest surviving line for both. The script highlights the range in the Neovim of the current tmux window. It starts a split if none exists. Ignore its output. If it prints an error, tell the user in one line and keep stepping. Do this on `next`, `back`, and `jump` too.
- **Never use `...` in a path.** It breaks fuzzy-finder matching in Telescope and fzf. This rule has no exceptions.
- **Long paths: truncate from the left.** Drop leading directory segments with no marker. Keep enough trailing segments to stay unique among the files in this review. If two truncated paths collide, show more segments.
- **Order:** most significant changes first, then supporting changes, then trivial ones such as config and formatting. Put implementation before its tests.
- **Skip trivial hunks:** pure reformatting, import changes with no logic change, and lint-only fixes get no step. Name those files in one summary line at the end.
- **Flag risks as you go:** describe each hunk in neutral terms. Call out bugs, risky spots, and concerns when you see them.
- **Keep each step short.** Aim for 10 lines or fewer. Use this shape:
  1. The header.
  2. One to three sentences on what the hunk changes.
  3. **Code check:** one to three bullets on what you verified against the code, such as identifiers, values, or behavior. Say what you did not verify. Omit the section if the hunk has no claims to check.
  4. **Concerns:** one to three bullets on bugs, risks, or unclear spots. Omit the section if you have none.
  5. One line asking the user to continue.
- Do the code check before you write the step. Do not show the commands.
- **On `stop` or `done`:** name the steps you did not review. List the problems and concerns noted so far. Do not edit files.

## Own work: handling problems

- When the user flags a problem in a hunk, note it. Keep stepping. Do not edit files during the walkthrough unless the user asks.
- At the end, list the noted problems. Ask whether to fix them before the push.
