# The fit git

A terminal-based Git workflow tool that provides an intuitive interface for common operations, built-in safety checks, and simple automation. The goal is to minimize the cognitive load on developers regarding Git operations. By providing a consistent, scalable workflow, the tool keeps teams in sync, maintains a clean commit history, and saves valuable "man-seconds."

## Installation

### Homebrew (macOS & Linux)

Install directly from this repository:

```bash
brew install marecht/fit/fit
```

After installation, run:

```bash
fit setup
```

### Manual Installation

```bash
git clone git@github.com:marecht/fit.git ~/.fit
echo 'export PATH="$HOME/.fit:$PATH"' >> ~/.zshrc
source ~/.zshrc
fit setup
```

## Commands

### Core Git Operations

- `fit rebase [branch]` - Sync and rebase onto a branch (defaults to DEFAULT_BRANCH)
- `fit commit [message] [-unsafe]` - Stage all changes and create/amend a commit
- `fit uncommit [-unsafe]` - Remove last commit but keep changes (soft reset)
- `fit push [message] [-unsafe]` - Commit, rebase, and force push with upstream
- `fit log` - Display git log in custom format

### Branch Management

- `fit branch <branch-name>` - Fetch all remotes and checkout a branch
- `fit new-branch <identificator> "commit message" [-id task_id]` - Create a new branch with formatted name and empty commit
  - Identificators: `add`, `change`, `update`, `fix`, `refactor`, `remove`
  - Branch format: `{task_id}_{identificator}-{formatted-commit}` or `{identificator}-{formatted-commit}`

### Stash Operations

- `fit stash [message]` - Stash changes with optional message
- `fit stash-pop` - Interactively select and apply a stash (removes from stash list)
- `fit stash-apply` - Interactively select and apply a stash (keeps in stash list)
- `fit stash-clear` - Delete all stashes (with confirmation)

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
- `f-gh-reviews` → `fit gh-reviews`
- `f-gh-checks` → `fit gh-checks`
- And more...

## Shell Completion

Both Zsh and Bash completion are automatically configured during `fit setup`:
- **Zsh**: Completion file installed to `~/.zshrc`
- **Bash**: Completion file installed to `~/.bashrc` or `/etc/bash_completion.d/fit`
- Completion works for both `fit` commands and `f-*` aliases
- Branch names are cached and suggested for `fit branch` command
- GitHub commands (`gh-reviews`, `gh-checks`) appear in completion only if GitHub integration is enabled

## Configuration

Configuration is stored in `~/.fit/config` (or `$BREW_PREFIX/opt/fit/config` for Homebrew installations):

- `DEFAULT_BRANCH` - Default branch name (usually "master" or "main")
- `GIT_USER_EMAIL` - Git user email
- `GIT_USER_NAME` - Git user name
- `USE_GITHUB` - Enable GitHub CLI integration ("true" or unset)

## Safety Checks

Most commands include safety checks to prevent accidental operations:
- `commit`, `uncommit`, and `push` verify that the local branch has new commits compared to `origin/DEFAULT_BRANCH`
- Use the `-unsafe` flag to bypass these checks when needed
- `stash-clear` requires explicit confirmation before deleting all stashes

## License

MIT
