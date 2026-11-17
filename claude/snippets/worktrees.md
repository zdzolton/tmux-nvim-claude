## Git worktrees

- Keep all cloned repos under `~/code/`.
- Do feature work in a sibling worktree named `<repo>-<feature-slug>`. Do not work in the main checkout.
  - Example: `git worktree add ../<repo>-<slug> -b <slug>`
- When feature work begins, run `prune-worktrees --no-prompt` from `~/code/`, outside any worktree. Run it without asking.
- Tell me which worktrees it kept and why. I decide about those in a terminal.
- Remove a review worktree when the review ends.
- Run `git branch -D` only after `gh pr list --state all --head <branch>` shows a merged PR. Squash merges hide merged work from `git branch -d`.
- Do not delete remote branches.
