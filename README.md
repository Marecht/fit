# Fit - Git Workflow Tool

A bash-based git workflow tool that provides a simplified interface for common git operations with safety checks, automatic rebasing, and a consistent workflow.

## Installation

### Homebrew (macOS & Linux)

```bash
brew install marecht/tap/fit
```

### Manual Installation

```bash
git clone https://github.com/marecht/fit.git ~/.fit
echo 'export PATH="$HOME/.fit:$PATH"' >> ~/.zshrc
source ~/.zshrc
fit setup
```

## Features

- **Simplified Commands**: Wrapper around common git operations
- **Safety Checks**: Prevents operations when branch has no new commits
- **Auto Rebase**: Automatically rebases before pushing
- **Color Coded Output**: Beautiful colored output with spinners
- **Zsh Completion**: Full tab completion support
- **Git Identity Management**: Stores git identity in config

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
