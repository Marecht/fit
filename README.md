# The fit git

A terminal-based git workflow tool that provides a different interface for common git operations with safety checks, and simple automations.
The goal is to minimise the need for a developer to think about git operations. This tool provides a consistent scalable workflow, which keeps everyone in sync, leaves a clean commit history and saves valuable "man seconds".  

## Installation

### Homebrew (macOS & Linux)

If you have a tap repository set up:

```bash
brew tap marecht/tap
brew install fit
```

Or install directly from this repository:

```bash
brew install marecht/fit/fit
```

After installation, run:

```bash
fit setup
```

### Manual Installation

```bash
git clone https://github.com/marecht/fit.git ~/.fit
echo 'export PATH="$HOME/.fit:$PATH"' >> ~/.zshrc
source ~/.zshrc
fit setup
```

## Commands

- `fit rebase [branch]` - Sync and rebase onto a branch
- `fit commit [message]` - Create or amend a commit
- `fit uncommit [-unsafe]` - Remove last commit (soft reset)
- `fit push [message] [-unsafe]` - Commit, rebase, and force push
- `fit log` - Display git log in custom format
- `fit setup` - Configure git identity and zsh completion

## Configuration

Configuration is stored in `~/.fit/config`:
- `DEFAULT_BRANCH` - Default branch name (usually "master" or "main")
- `GIT_USER_EMAIL` - Git user email
- `GIT_USER_NAME` - Git user name

## License

MIT
