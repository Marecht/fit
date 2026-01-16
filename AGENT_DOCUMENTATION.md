# Fit - Git Workflow Tool Documentation

## Overview

Fit is a bash-based git workflow tool that provides a simplified interface for common git operations. It wraps git commands with safety checks, automatic rebasing, and a consistent workflow.

## Project Structure

```
~/.fit/
├── fit.sh              # Main script with all commands
├── config              # Configuration file (DEFAULT_BRANCH, GIT_USER_EMAIL, GIT_USER_NAME)
├── _fit                # Zsh completion file
└── AGENT_DOCUMENTATION.md  # This file
```

## Configuration

The `config` file stores:
- `DEFAULT_BRANCH`: Default branch name (usually "master" or "main")
- `GIT_USER_EMAIL`: Git user email (set via `fit setup`)
- `GIT_USER_NAME`: Git user name (set via `fit setup`)

## Commands

### `fit rebase [branch]`
Syncs and rebases the current branch onto `origin/[branch]` (defaults to `DEFAULT_BRANCH`).
- Fetches all remotes and prunes
- Rebases onto the target branch

### `fit commit [message]`
Creates or amends a commit.
- **Without message**: Amends the last commit (requires origin check)
- **With message**: Creates a new commit (bypasses origin check)
- Always uses `--allow-empty` flag
- Sets git identity from config before committing

### `fit uncommit [-unsafe]`
Removes the last commit using soft reset (keeps changes staged).
- Requires origin check unless `-unsafe` flag is used
- Preserves all changes in the staging area

### `fit push [message] [-unsafe]`
Complete push workflow:
1. Commits/amends (with or without message)
2. Rebases onto `DEFAULT_BRANCH`
3. Force pushes if rebase succeeds
- **Without message**: Amends (requires origin check)
- **With message**: Creates new commit (bypasses origin check)
- Fails if rebase has conflicts

### `fit check-unsafe origin`
Manually checks if local branch has new commits compared to `origin/DEFAULT_BRANCH`.
- Returns success message if check passes
- Used for testing the check logic

### `fit setup`
Interactive setup command:
- Prompts for git identity (email and name) if not configured
- Saves identity to config file
- Sets up zsh completion in `~/.zshrc`
- Updates completion even if already configured

## Safety Checks

### Origin Check (`check_origin`)

The origin check prevents certain operations when the local branch has no new commits compared to `origin/DEFAULT_BRANCH`.

**When it runs:**
- Before `commit` (when amending, not when creating new commit)
- Before `uncommit`
- Before `push` (when amending, not when creating new commit)

**When it's bypassed:**
- When `-unsafe` flag is provided
- When creating a new commit (with message)
- If origin ref doesn't exist
- If not in a git repository

**Logic:**
1. Fetches all remotes
2. Compares local HEAD with `origin/DEFAULT_BRANCH`
3. Counts commits ahead
4. Fails if ahead count is 0

## Color Coding Standards

All output must follow these color standards:

- **Errors (RED)**: Use `error()` function
  - Error messages
  - Validation failures
  - Blocked actions

- **Actions (TEAL)**: Use `action()` function
  - Current action being performed (format: `--- Action Description ---`)
  - Setup completion messages

- **Info (GRAY)**: Use `info()` function
  - Informational messages
  - Status updates
  - Usage instructions
  - Success confirmations

**Implementation:**
```bash
RED='\033[0;31m'
TEAL='\033[0;36m'
GRAY='\033[0;90m'
RESET='\033[0m'

error() {
    echo -e "${RED}$1${RESET}"
}

action() {
    echo -e "${TEAL}$1${RESET}"
}

info() {
    echo -e "${GRAY}$1${RESET}"
}
```

## Adding New Commands

When adding a new command, follow these steps:

1. **Add command case** in the main `case "$COMMAND" in` block
2. **Update usage message** in the `*)` default case
3. **Update zsh completion** in `_fit` file:
   - Add to `commands` array with description
   - Add argument handling in `args` case if needed
   - Add `-unsafe` flag support if command should respect it
4. **Apply color coding**:
   - Use `action()` for action messages
   - Use `error()` for errors
   - Use `info()` for informational output
5. **Consider safety checks**:
   - Should it run `check_origin`?
   - Should it respect `-unsafe` flag?
   - Should it check git identity?

## Argument Parsing

The script uses a custom argument parser:
- `COMMAND`: First argument
- `UNSAFE_FLAG`: Detected from any `-unsafe` argument
- `ARG1`, `ARG2`: Non-flag arguments (excluding command and `-unsafe`)

The parser filters out `-unsafe` from regular arguments.

## Git Identity Management

Git identity is stored in the config file and set locally (not globally) for each repository:
- Loaded from config at script start
- Set via `git config user.email` and `git config user.name` (local scope)
- Required before any commit operations
- Configured via `fit setup`

## Zsh Completion

The completion file `_fit` provides:
- Command suggestions
- Branch name suggestions for `rebase`
- Commit message support for `commit` and `push`
- `-unsafe` flag suggestions where applicable

**Setup:**
- Added to `fpath` in `~/.zshrc`
- Automatically loaded by zsh completion system
- Updated when `fit setup` is run

**When adding new commands:**
- Add to `commands` array
- Add argument handling in `args` case
- Test completion after changes

## Error Handling

- All errors exit with `exit 1`
- Error messages use red color
- Validation errors show clear instructions
- Git operations fail gracefully with error messages

## Best Practices

1. **Always use color functions** for output (never plain `echo`)
2. **Check git identity** before commit operations
3. **Run origin check** when modifying existing commits
4. **Allow bypass** with `-unsafe` for safety checks
5. **Update completion** when adding commands
6. **Test commands** in a git repository
7. **Use `--allow-empty`** for commits to allow empty commits
8. **Fetch before checks** to ensure up-to-date remote information

## Testing

Test commands in a git repository:
- Create a test branch
- Make commits
- Test with and without `-unsafe` flag
- Verify color output
- Test zsh completion

## Notes

- All commits use `--allow-empty` flag
- Rebase always fetches and prunes first
- Push always force pushes after successful rebase
- Git identity is set locally, not globally
- Completion is automatically updated on setup
