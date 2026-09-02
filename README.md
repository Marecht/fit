# FIT: The Focused Git Tool

A terminal-based Git workflow tool that provides an intuitive interface for common operations, built-in safety checks, and simple automation. The goal is to minimize the cognitive load on developers regarding Git operations. By providing a consistent, scalable workflow, the tool keeps teams in sync, maintains a clean commit history, prevents complicated merge conflicts and saves valuable "man-seconds."

## Installation

### Homebrew (Linux)

Install directly from this repository:

```bash
brew install marecht/fit/fit
fit setup
```

### Manual Installation (Linux)

```bash
git clone git@github.com:marecht/fit.git ~/.fit
echo 'export PATH="$HOME/.fit:$PATH"' >> ~/.zshrc
source ~/.zshrc
fit setup
```

You will be prompted to choose the default branch.
If you work in repositories with different default branches, you can set it for each individually. Run this in a repository:

```bash
fit default-repository-branch master # or main etc...
```

# Workflow Rules & The "FIT" Philosophy

### 1. Maintain a Linear History (Continuous Rebase)
Avoid merge commits entirely. Use rebasing to keep your feature branch's history linear and frequently sync with the `main` branch to prevent drift. This ensures your work appears as a straight line of progress rather than a complex web of junctions, while also preventing "conflict debt" from piling up.

* **Linear Integration:** Standard Git makes merging the "path of least resistance." `fit` reverses this by making rebasing the default way to integrate changes. All operations use rebase, ensuring a clean history is the natural outcome.
* **Conflict Prevention & CI Efficiency:** By rebasing with `main` frequently, you resolve conflicts while the context is fresh. This prevents GitHub Runners from wasting resources on PRs that are already out of date or broken.
* **Automation:** `fit` handles rebasing automatically at logical checkpoints, making updates from `main` invisible and routine. It acts as a safety gate, preventing pushes if a conflict exists, which keeps the remote repository and CI pipeline "green" at all times.

### 2. Atomic Features and Working State
Keep the commit count to a minimum by ensuring each commit represents a complete, logical feature rather than a series of "work in progress" snapshots. Every commit must leave the application in a functional, working state, making the project history readable and ensuring the codebase remains stable for conflict resolution.

* **Curated History:** `fit` recognizes that "checkpoint" commits are a safety net but a project's clutter. It provides streamlined "amend" or "absorb" logic, allowing you to save progress locally while automatically squashing changes into a single logical commit.
* **Temporary Commits for Checkpoints:** When you need checkpoint commits during development (for safety, testing, or context switching), `fit temp` allows you to create temporary commits that are clearly marked and easily squashed later. These commits let you save progress frequently without cluttering your final history. When ready to ship, `fit ship` automatically squashes all temp commits in each stack into a single atomic commit, preserving only the feature-level message while maintaining a clean, readable history.
* **Feature-Centric Development:** By reducing the friction of rewriting history, `fit` encourages you to curate your work. Its interface emphasizes the "Feature" over the "File Change," prompting you to finalize work only when it adds distinct value to the overall application context. The temp commit workflow bridges the gap between the safety of frequent checkpoints and the clarity of atomic feature commits.

### 3. Single-Person Branches
Each branch should be worked on by a single person. This avoids "collaboration friction" and prevents the need for complex internal merges within a feature branch.

* Since `fit` is optimized for a linear, rebase-heavy workflow, it assumes a high level of branch ownership.
* Your local version of the branch is always the source of truth unless choose otherwise.

### 4. Safety Through Automation
`fit` doesn't just suggest best practices—it enforces them through built-in safety checks and automated workflows. This reduces decision fatigue and prevents common mistakes before they become problems.

* **Proactive Conflict Prevention:** `fit` automatically rebases before pushing, ensuring conflicts are resolved locally before they reach the remote repository. If a conflict exists, the push is blocked, keeping CI pipelines green and preventing broken states from propagating.
* **Origin Validation:** Commands like `commit`, `uncommit`, and `push` verify that your branch contains new work compared to the default branch. This prevents accidental operations on branches that are already in sync, reducing the risk of force-pushing over existing work.
* **Fail-Safe Defaults:** The `-unsafe` flag exists for edge cases, but the default behavior prioritizes safety. This ensures that the "path of least resistance" aligns with best practices rather than shortcuts that create technical debt.

## Example

### Raw git:

```bash
git checkout -b add-user-authentication

# Make your changes, edit files...

git add .
git commit -m "Add user authentication feature"

git push -u origin add-user-authentication

# There are conflicts. You need to resolve them. CI pipline is already running.

git fetch --all
git rebase origin/main

# Resolve conflicts manually

git add .
git rebase --continue

git push --force origin add-user-authentication

# CI pipline runs again
```

### Fit:

```bash
# Create branch "add-user-authentication-feature" and empty commit "Added user authentication feature"
fit new-branch add "user authentication feature" 

# Make your changes, edit files...

# Amend the existing commit and push
fit push 

# There are conflicts, command doesn't push but makes you solve them first locally (while context is fresh)

fit rebase-continue

fit push

# Your branch is now pushed with conflicts resolved
# CI pipeline stays green because conflicts were resolved before push
```

## Commands

### Core Git Operations

- `fit rebase [branch]` - Sync and rebase onto a branch (defaults to DEFAULT_BRANCH)
- `fit commit [message] [-unsafe]` - Stage all changes and create/amend a commit
- `fit uncommit [-unsafe]` - Remove last commit but keep changes (soft reset)
- `fit push [message] [-unsafe]` - Commit, rebase, and force push with upstream
- `fit temp [message]` - Create temporary commits for checkpointing during development
  - With message: Creates a new temp commit stack
  - Without message: Adds to existing temp commit stack (if last commit is a temp commit)
- `fit ship` - Squash all temp commit stacks into atomic commits and push
- `fit log` - Display git log in custom format

### Branch Management

- `fit branch <branch-name>` - Fetch all remotes and checkout a branch
- `fit new-branch <identificator> "commit message" [-id task_id]` - Create a new branch with formatted name and empty commit
  - Identificators: `add`, `change`, `update`, `fix`, `refactor`, `remove`
  - Branch format: `{task_id}_{identificator}-{formatted-commit}` or `{identificator}-{formatted-commit}`
  - **Jira Integration**: If Jira is configured, typing the commit message will autosuggest Jira issue summaries. Selecting an issue automatically prefills both the commit message and the `-id` flag with the corresponding issue key.

### Stash Operations

- `fit stash [message]` - Stash changes with optional message
- `fit stash-pop` - Interactively select and apply a stash (removes from stash list)
- `fit stash-apply` - Interactively select and apply a stash (keeps in stash list)
- `fit stash-clear` - Delete all stashes (with confirmation)
- `fit snapshot [message]` - Stash changes and immediately re-apply them, keeping the stash as a restore point

### Worktrees

- `fit worktree-create [name]` - Move the current state of the branch you are on into a new worktree and print its path
  - Uncommitted changes are moved along, so the repository you ran it from is left clean
  - The worktree gets its own branch (`<current-branch>-worktree` by default), because git cannot check out one branch in two worktrees
  - Worktrees are created in `<repo>-worktrees` next to the main repository
  - Only the path is printed to stdout, so it composes: `cd "$(fit worktree-create)"`
- `fit worktree-checkout` - List every worktree and print the path of the one you pick, so you can jump to it
  - Lists all worktrees, including the ones without uncommitted changes
  - Nothing is checked out or modified, it only prints a path: `cd "$(fit worktree-checkout)"`
- `fit worktree-merge [-all]` - Bring the work from a worktree into the main repository as uncommitted changes
  - Lists the worktrees that have uncommitted changes and asks which one to merge
  - Worktrees with nothing uncommitted are hidden from the list (but left untouched); `-all` lists them too, which is what you need for a worktree whose work is already committed
  - Asks for the branch the work should end up on (created if it doesn't exist)
  - Commits everything in the worktree, deletes the worktree, checks out the target branch in the main repository and leaves the changes staged but uncommitted
  - If the target branch is new, the worktree's own commit history is kept and only the final commit is uncommitted
  - If the target branch already exists, the worktree's work is squashed on top of it so its history stays intact
  - Must be run from the main repository (not from inside the worktree being merged), and the main repository must have no uncommitted changes

Both selection lists are ordered by creation date with the newest worktree at the bottom as `[0]`, closest to the prompt. If the filesystem doesn't report creation times, git's own order is kept.

### GitHub Integration (requires GitHub CLI)

- `fit gh-reviews` - Show PR review status for all branches (pending, approved, changes requested)
- `fit gh-checks` - Show CI checks status for all branches

### Utilities

- `fit setup` - Configure git identity, default branch, shell completion, aliases, and GitHub integration
- `fit help` - Display detailed help for all commands

## Aliases

The `fit setup` command automatically creates aliases for all commands (except `setup`, `check-unsafe`, and `approved`):
- `f-rebase` → `fit rebase`
- `f-commit` → `fit commit`
- `f-push` → `fit push`
- `f-branch` → `fit branch`
- `f-new-branch` → `fit new-branch`
- `f-stash` → `fit stash`
- `f-stash-pop` → `fit stash-pop`
- `f-stash-apply` → `fit stash-apply`
- `f-stash-clear` → `fit stash-clear`
- `f-worktree-create` → `fit worktree-create`
- `f-worktree-checkout` → `fit worktree-checkout`
- `f-worktree-merge` → `fit worktree-merge`
- `f-gh-reviews` → `fit gh-reviews`
- `f-gh-checks` → `fit gh-checks`
- And more...

## Shell Completion

Both Zsh and Bash completion are automatically configured during `fit setup`:
- **Zsh**: Completion file installed to `~/.zshrc`
- **Bash**: Completion file installed to `~/.bashrc` or `/etc/bash_completion.d/fit`
- Completion works for both `fit` commands and `f-*` aliases
- Branch names are cached and suggested for `fit branch` command
- **Jira Integration**: If Jira is configured, `fit new-branch` will autosuggest Jira issue summaries when typing the commit message. Selecting an issue automatically prefills the commit message with the issue summary and the `-id` flag with the issue key.
- GitHub commands (`gh-reviews`, `gh-checks`) appear in completion only if GitHub integration is enabled

## Configuration

Configuration is stored in `~/.fit/config` (or `$BREW_PREFIX/opt/fit/config` for Homebrew installations):

- `DEFAULT_BRANCH` - Default branch name (usually "master" or "main")
- `GIT_USER_EMAIL` - Git user email
- `GIT_USER_NAME` - Git user name
- `USE_GITHUB` - Enable GitHub CLI integration ("true" or unset)
- `PROJECT_MANAGER` - Project manager integration ("jira" or "none")

## Safety Checks

Most commands include safety checks to prevent accidental operations:
- `commit`, `uncommit`, and `push` verify that the local branch has new commits compared to `origin/DEFAULT_BRANCH`
- Use the `-unsafe` flag to bypass these checks when needed
- `stash-clear` requires explicit confirmation before deleting all stashes


## License

MIT