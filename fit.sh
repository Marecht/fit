#!/bin/bash

# Color codes
RED='\033[0;31m'
TEAL='\033[0;36m'
GRAY='\033[0;90m'
CYAN='\033[0;96m'
YELLOW='\033[0;33m'
WHITE='\033[0;97m'
RESET='\033[0m'

# Spinner characters
SPINNER_CHARS="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

# Global indentation prefix
INDENT="   "

# Animated spinner function
spinner() {
    local pid=$1
    local message="$2"
    local spin_idx=0
    
    while kill -0 $pid 2>/dev/null; do
        local spin_char="${SPINNER_CHARS:$spin_idx:1}"
        printf "\r${INDENT}${TEAL}%-60s${RESET} [${TEAL}${spin_char}${RESET}]" "$message"
        spin_idx=$(((spin_idx + 1) % ${#SPINNER_CHARS}))
        sleep 0.1
    done
}

# Color helper functions
error() {
    echo -e "${INDENT}${INDENT}${RED}$1${RESET}"
}

action_start() {
    local message="$1"
    printf "${INDENT}${TEAL}%-60s${RESET} [${TEAL}⠋${RESET}]" "$message"
}

action_end() {
    local message="$1"
    printf "\r${INDENT}${TEAL}%-60s${RESET} [${TEAL}✓${RESET}]\n" "$message"
}

action_with_spinner() {
    local message="$1"
    shift
    local temp_file=$(mktemp)
    
    action_start "$message"
    (command "$@" > "$temp_file" 2>&1) &
    local pid=$!
    spinner $pid "$message" &
    local spinner_pid=$!
    wait $pid
    local exit_code=$?
    kill $spinner_pid 2>/dev/null
    wait $spinner_pid 2>/dev/null
    printf "\r"
    action_end "$message"
    rm -f "$temp_file"
    return $exit_code
}

action_with_spinner_and_output() {
    local message="$1"
    shift
    local temp_file=$(mktemp)
    
    action_start "$message"
    (command "$@" > "$temp_file" 2>&1) &
    local pid=$!
    spinner $pid "$message" &
    local spinner_pid=$!
    wait $pid
    local exit_code=$?
    kill $spinner_pid 2>/dev/null
    wait $spinner_pid 2>/dev/null
    printf "\r"
    action_end "$message"
    
    while IFS= read -r line || [ -n "$line" ]; do
        if [ -n "$line" ]; then
            if [ $exit_code -ne 0 ]; then
                error "$line"
            else
                info "$line"
            fi
        fi
    done < "$temp_file"
    rm -f "$temp_file"
    return $exit_code
}

action() {
    local message="$1"
    action_start "$message"
    action_end "$message"
}

info() {
    echo -e "${INDENT}${INDENT}${GRAY}- $1${RESET}"
}

# Git command wrapper to color output gray
run_git() {
    local temp_file=$(mktemp)
    command git "$@" > "$temp_file" 2>&1
    local exit_code=$?
    while IFS= read -r line || [ -n "$line" ]; do
        [ -n "$line" ] && info "$line"
    done < "$temp_file"
    rm -f "$temp_file"
    return $exit_code
}

# Determine fit directory (Homebrew or local installation)
BREW_PREFIX=""
if command -v brew >/dev/null 2>&1; then
    BREW_PREFIX="$(brew --prefix 2>/dev/null)"
fi

if [[ -n "$BREW_PREFIX" ]] && [[ -f "$BREW_PREFIX/opt/fit/config" ]]; then
    FIT_DIR="$BREW_PREFIX/opt/fit"
    FIT_CONFIG="$FIT_DIR/config"
elif [[ -f "$HOME/.fit/config" ]]; then
    FIT_DIR="$HOME/.fit"
    FIT_CONFIG="$HOME/.fit/config"
else
    FIT_DIR="${0%/*}"
    FIT_CONFIG="$FIT_DIR/config"
fi

# Create config if it doesn't exist
if [[ ! -f "$FIT_CONFIG" ]]; then
    mkdir -p "$(dirname "$FIT_CONFIG")"
    echo 'DEFAULT_BRANCH="master"' > "$FIT_CONFIG"
fi

# Load config and trim hidden characters
source "$FIT_CONFIG"
DEFAULT_BRANCH=$(echo "$DEFAULT_BRANCH" | tr -d '\r' | xargs)
GIT_USER_EMAIL=$(echo "$GIT_USER_EMAIL" | tr -d '\r' | xargs)
GIT_USER_NAME=$(echo "$GIT_USER_NAME" | tr -d '\r' | xargs)
USE_GITHUB=$(echo "$USE_GITHUB" | tr -d '\r' | xargs)

COMMAND=$1
UNSAFE_FLAG=false
TASK_ID=""
ARG1=""
ARG2=""

# Parse arguments, handling -id and -unsafe flags
shift
i=1
while [ $i -le $# ]; do
    arg="${!i}"
    case "$arg" in
        -unsafe)
            UNSAFE_FLAG=true
            ;;
        -id)
            if [ $i -lt $# ]; then
                i=$((i + 1))
                TASK_ID="${!i}"
            fi
            ;;
        *)
            if [ -z "$ARG1" ]; then
                ARG1="$arg"
            elif [ -z "$ARG2" ]; then
                ARG2="$arg"
            fi
            ;;
    esac
    i=$((i + 1))
done

# Helper function to check and set git identity
check_git_identity() {
    if [ -z "$GIT_USER_EMAIL" ] || [ -z "$GIT_USER_NAME" ]; then
        error "ERROR: Git user identity not configured! Please run: fit setup"
        exit 1
    fi
    
    git config user.email "$GIT_USER_EMAIL"
    git config user.name "$GIT_USER_NAME"
}

# Helper function to check if local branch has new commits compared to origin
check_origin() {
    if [ "$UNSAFE_FLAG" = "true" ]; then
        return 0
    fi
    
    action_with_spinner "Checking origin/$DEFAULT_BRANCH" git fetch --all --prune
    
    local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -z "$current_branch" ]; then
        return 0
    fi
    
    local origin_ref="origin/$DEFAULT_BRANCH"
    if ! git rev-parse --verify "$origin_ref" >/dev/null 2>&1; then
        return 0
    fi
    
    local local_commit=$(git rev-parse HEAD 2>/dev/null)
    local origin_commit=$(git rev-parse "$origin_ref" 2>/dev/null)
    
    if [ -z "$local_commit" ] || [ -z "$origin_commit" ]; then
        return 0
    fi
    
    if git merge-base --is-ancestor "$origin_commit" "$local_commit" 2>/dev/null; then
        local ahead=$(git rev-list --count "$origin_commit".."$local_commit" 2>/dev/null)
        if [ "$ahead" -eq 0 ]; then
            error "ERROR:  Action not permitted. There are no new changes in this branch. If you want to side step this check use the -unsafe flag."
            exit 1
        fi
    else
        return 0
    fi
}

# Helper function to run rebase logic
do_commit() {
    local commit_message="$1"
    
    action_with_spinner "Staging All Changes" git add -A
    
    if [ -z "$commit_message" ]; then
        check_origin
        action_with_spinner_and_output "Amending Commit" git commit --amend --no-edit --allow-empty
    else
        action_with_spinner_and_output "Creating New Commit" git commit -m "$commit_message" --allow-empty
    fi
}

save_branch_cache() {
    local cache_file="$FIT_DIR/.branch_cache"
    git branch -r --format='%(refname:short)' 2>/dev/null | sed 's|origin/||' | sort -u > "$cache_file" 2>/dev/null || true
}

# Helper function to format commit message to branch name (lowercase, hyphen-separated)
format_commit_for_branch() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g'
}

# Helper function to get past tense of identificator
get_past_tense() {
    case "$1" in
        add) echo "Added" ;;
        change) echo "Changed" ;;
        update) echo "Updated" ;;
        fix) echo "Fixed" ;;
        refactor) echo "Refactored" ;;
        remove) echo "Removed" ;;
        *) echo "$1" ;;
    esac
}

# Helper function to capitalize first letter
capitalize() {
    echo "$1" | sed 's/^./\U&/'
}

do_rebase() {
    local target=${1:-$DEFAULT_BRANCH}
    action_with_spinner "Syncing with origin/$target" git fetch --all --prune
    save_branch_cache
    local rebase_exit_code
    action_with_spinner_and_output "Rebasing with origin/$target" git rebase "origin/$target"
    rebase_exit_code=$?
    if [ $rebase_exit_code -ne 0 ]; then
        return $rebase_exit_code
    fi
}

# Helper function to display git log
show_log() {
    local log_args=()
    for arg in "$@"; do
        if [ "$arg" != "-unsafe" ]; then
            log_args+=("$arg")
        fi
    done
    
    git log --format="%ai|%an|%ae|%h|%s" "${log_args[@]}" | while IFS='|' read -r date author email commit_id message; do
        local formatted_date=$(echo "$date" | awk '{print $1 " " substr($2, 1, 5)}')
        echo -e "${YELLOW}[${formatted_date}]${RESET} ${CYAN}${author} <${email}>${RESET} ${GRAY}${commit_id}${RESET}"
        echo -e "${INDENT}${INDENT}${WHITE}- ${message}${RESET}"
        echo
    done | less -R
}

show_stash_list_and_select() {
    local stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
    if [ -z "$stash_count" ] || [ "$stash_count" -eq 0 ]; then
        info "No stashes found." >&2
        return 1
    fi
    
    echo "" >&2
    echo -e "${TEAL}Stash List:${RESET}" >&2
    echo "" >&2
    
    local index=0
    while [ $index -lt "$stash_count" ]; do
        local stash_ref="stash@{$index}"
        local stash_info=$(git log --format="%ad|%s" --date=local -1 "$stash_ref" 2>/dev/null)
        
        if [ -z "$stash_info" ]; then
            index=$((index + 1))
            continue
        fi
        
        local date=$(echo "$stash_info" | cut -d'|' -f1)
        local message=$(echo "$stash_info" | cut -d'|' -f2-)
        local branch=""
        local stash_message=""
        
        if echo "$message" | grep -q "^WIP on"; then
            branch=$(echo "$message" | sed -n 's/^WIP on \([^:]*\):.*/\1/p')
            stash_message=$(echo "$message" | sed -n 's/^WIP on [^:]*: [^ ]* \(.*\)/\1/p')
        elif echo "$message" | grep -q "^On "; then
            branch=$(echo "$message" | sed -n 's/^On \([^:]*\):.*/\1/p')
            stash_message=$(echo "$message" | sed -n 's/^On [^:]*: \(.*\)/\1/p')
        else
            branch=$(git log --format="%D" -1 "$stash_ref" 2>/dev/null | grep -oE "HEAD -> [^,)]*" | sed 's/HEAD -> //' | head -1)
            if [ -z "$branch" ]; then
                branch="unknown"
            fi
            stash_message="$message"
        fi
        
        if [ -z "$stash_message" ]; then
            stash_message="(no message)"
        fi
        
        echo -e "${INDENT}${CYAN}[$index] stash@{$index}${RESET}" >&2
        echo -e "${INDENT}${INDENT}${YELLOW}Date:${RESET} ${GRAY}$date${RESET}" >&2
        echo -e "${INDENT}${INDENT}${YELLOW}Branch:${RESET} ${GRAY}$branch${RESET}" >&2
        echo -e "${INDENT}${INDENT}${YELLOW}Message:${RESET} ${GRAY}$stash_message${RESET}" >&2
        echo "" >&2
        
        index=$((index + 1))
    done
    
    echo -e "${TEAL}Select a stash (0-$((stash_count - 1))):${RESET} " >&2
    read -r selected_index < /dev/tty
    
    if [ -z "$selected_index" ]; then
        info "No selection made. Exiting." >&2
        return 1
    fi
    
    if ! [[ "$selected_index" =~ ^[0-9]+$ ]] || [ "$selected_index" -lt 0 ] || [ "$selected_index" -ge "$stash_count" ]; then
        error "Invalid selection. Please enter a number between 0 and $((stash_count - 1))." >&2
        return 1
    fi
    
    echo "$selected_index"
    return 0
}

show_help() {
    echo -e "${WHITE}fit - Git workflow automation tool${RESET}"
    echo ""
    echo -e "${TEAL}COMMANDS:${RESET}"
    echo ""
    
    echo -e "${CYAN}fit rebase [branch]${RESET}"
    echo -e "${INDENT}${GRAY}Syncs and rebases the current branch onto the specified branch (defaults to DEFAULT_BRANCH).${RESET}"
    echo -e "${INDENT}${GRAY}Parameters:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- branch (optional): Target branch to rebase onto. Defaults to DEFAULT_BRANCH from config.${RESET}"
    echo -e "${INDENT}${GRAY}Git commands executed:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git fetch --all --prune${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git rebase origin/<branch>${RESET}"
    echo ""
    
    echo -e "${CYAN}fit branch <branch-name>${RESET}"
    echo -e "${INDENT}${GRAY}Fetches all remotes and checks out the specified branch.${RESET}"
    echo -e "${INDENT}${GRAY}Parameters:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- branch-name (required): Name of the branch to checkout.${RESET}"
    echo -e "${INDENT}${GRAY}Git commands executed:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git fetch --all --prune${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git checkout <branch-name>${RESET}"
    echo ""
    
    echo -e "${CYAN}fit new-branch <identificator> \"commit message\" [-id task_id]${RESET}"
    echo -e "${INDENT}${GRAY}Creates a new branch with a formatted name and an empty commit.${RESET}"
    echo -e "${INDENT}${GRAY}Parameters:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- identificator (required): One of: add, change, update, fix, refactor, remove${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- commit message (required): The commit message for the initial commit${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- -id task_id (optional): Task identifier to prefix the branch name${RESET}"
    echo -e "${INDENT}${GRAY}Branch name format:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- With task_id: {task_id}_{identificator}-{formatted-commit-message}${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- Without task_id: {identificator}-{formatted-commit-message}${RESET}"
    echo -e "${INDENT}${GRAY}Git commands executed:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git checkout -b <branch-name>${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git commit --allow-empty -m \"<past-tense-identificator> <commit-message>\"${RESET}"
    echo ""
    
    echo -e "${CYAN}fit log [git-log-args]${RESET}"
    echo -e "${INDENT}${GRAY}Displays git log in a custom formatted, colorized view with pager support.${RESET}"
    echo -e "${INDENT}${GRAY}Parameters:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git-log-args (optional): Any arguments accepted by git log (e.g., -n 10, --oneline, etc.)${RESET}"
    echo -e "${INDENT}${GRAY}Git commands executed:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git log --format=\"%ai|%an|%ae|%h|%s\" [args]${RESET}"
    echo -e "${INDENT}${GRAY}Output format:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}[date] author <email> commit_id${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}   - Commit message${RESET}"
    echo ""
    
    echo -e "${CYAN}fit stash [message]${RESET}"
    echo -e "${INDENT}${GRAY}Stashes the current working directory changes.${RESET}"
    echo -e "${INDENT}${GRAY}Parameters:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- message (optional): Stash message. If omitted, stashes without a message.${RESET}"
    echo -e "${INDENT}${GRAY}Git commands executed:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git stash push -m \"<message>\" (if message provided)${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git stash push (if no message)${RESET}"
    echo ""
    
    echo -e "${CYAN}fit stash-pop${RESET}"
    echo -e "${INDENT}${GRAY}Displays a formatted list of all stashes and prompts you to select one.${RESET}"
    echo -e "${INDENT}${GRAY}Applies the selected stash and removes it from the stash list.${RESET}"
    echo -e "${INDENT}${GRAY}Parameters:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- None (interactive selection)${RESET}"
    echo -e "${INDENT}${GRAY}Git commands executed:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git log --format=\"%ad|%s\" --date=local -1 stash@{index}${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git stash pop stash@{selected_index}${RESET}"
    echo ""
    
    echo -e "${CYAN}fit stash-apply${RESET}"
    echo -e "${INDENT}${GRAY}Displays a formatted list of all stashes and prompts you to select one.${RESET}"
    echo -e "${INDENT}${GRAY}Applies the selected stash but keeps it in the stash list.${RESET}"
    echo -e "${INDENT}${GRAY}Parameters:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- None (interactive selection)${RESET}"
    echo -e "${INDENT}${GRAY}Git commands executed:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git log --format=\"%ad|%s\" --date=local -1 stash@{index}${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git stash apply stash@{selected_index}${RESET}"
    echo ""
    
    echo -e "${CYAN}fit stash-clear${RESET}"
    echo -e "${INDENT}${GRAY}Deletes all stashes after confirmation.${RESET}"
    echo -e "${INDENT}${GRAY}Parameters:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- None (interactive confirmation)${RESET}"
    echo -e "${INDENT}${GRAY}Git commands executed:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git stash clear${RESET}"
    echo ""
    
    if [ "$USE_GITHUB" = "true" ]; then
        echo -e "${CYAN}fit gh-reviews${RESET}"
        echo -e "${INDENT}${GRAY}Displays all branches and their pull request review status.${RESET}"
        echo -e "${INDENT}${GRAY}Shows: pending, approved, or changes requested.${RESET}"
        echo -e "${INDENT}${GRAY}Parameters:${RESET}"
        echo -e "${INDENT}${INDENT}${GRAY}- None${RESET}"
        echo -e "${INDENT}${GRAY}GitHub CLI commands executed:${RESET}"
        echo -e "${INDENT}${INDENT}${GRAY}- gh pr list --repo <repo> --head <branch>${RESET}"
        echo -e "${INDENT}${INDENT}${GRAY}- gh pr view <number> --repo <repo>${RESET}"
        echo ""
        
        echo -e "${CYAN}fit gh-checks${RESET}"
        echo -e "${INDENT}${GRAY}Displays all branches and their CI checks status.${RESET}"
        echo -e "${INDENT}${GRAY}Shows: passed, failed, or pending checks for each PR.${RESET}"
        echo -e "${INDENT}${GRAY}Parameters:${RESET}"
        echo -e "${INDENT}${INDENT}${GRAY}- None${RESET}"
        echo -e "${INDENT}${GRAY}GitHub CLI commands executed:${RESET}"
        echo -e "${INDENT}${INDENT}${GRAY}- gh pr list --repo <repo> --head <branch>${RESET}"
        echo -e "${INDENT}${INDENT}${GRAY}- gh pr checks <number> --repo <repo>${RESET}"
        echo ""
    fi
    
    echo -e "${CYAN}fit commit [message] [-unsafe]${RESET}"
    echo -e "${INDENT}${GRAY}Stages all changes and creates a new commit or amends the last commit.${RESET}"
    echo -e "${INDENT}${GRAY}Parameters:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- message (optional): Commit message. If omitted, amends the last commit.${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- -unsafe (optional): Bypasses the safety check for new commits when amending.${RESET}"
    echo -e "${INDENT}${GRAY}Git commands executed:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git add -A${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git commit -m \"<message>\" --allow-empty (if message provided)${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git commit --amend --no-edit --allow-empty (if no message)${RESET}"
    echo -e "${INDENT}${GRAY}Safety check:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- Verifies local branch has new commits compared to origin/DEFAULT_BRANCH (when amending, unless -unsafe flag is used)${RESET}"
    echo ""
    
    echo -e "${CYAN}fit uncommit [-unsafe]${RESET}"
    echo -e "${INDENT}${GRAY}Removes the last commit from history but keeps all changes in the staging area (soft reset).${RESET}"
    echo -e "${INDENT}${GRAY}Parameters:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- -unsafe (optional): Bypasses the safety check for new commits.${RESET}"
    echo -e "${INDENT}${GRAY}Git commands executed:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git reset --soft HEAD~1${RESET}"
    echo -e "${INDENT}${GRAY}Safety check:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- Verifies local branch has new commits compared to origin/DEFAULT_BRANCH (unless -unsafe flag is used)${RESET}"
    echo ""
    
    echo -e "${CYAN}fit push [message] [-unsafe]${RESET}"
    echo -e "${INDENT}${GRAY}Commits (or amends), rebases, and force pushes the current branch.${RESET}"
    echo -e "${INDENT}${GRAY}Parameters:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- message (optional): Commit message. If omitted, amends the last commit.${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- -unsafe (optional): Bypasses the safety check for new commits when amending.${RESET}"
    echo -e "${INDENT}${GRAY}Commands executed:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- fit commit [message] [-unsafe]${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- fit rebase${RESET}"
    echo -e "${INDENT}${GRAY}Git commands executed:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git push --force --set-upstream origin <branch>${RESET}"
    echo ""
    
    echo -e "${CYAN}fit setup${RESET}"
    echo -e "${INDENT}${GRAY}Configures git identity, default branch, zsh completion, and creates command aliases.${RESET}"
    echo -e "${INDENT}${GRAY}Parameters:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- None (interactive prompts)${RESET}"
    echo -e "${INDENT}${GRAY}Configuration saved to:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- ~/.fit/config (or \$BREW_PREFIX/opt/fit/config for Homebrew)${RESET}"
    echo -e "${INDENT}${GRAY}Actions performed:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- Prompts for DEFAULT_BRANCH if not configured${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- Prompts for GIT_USER_EMAIL if not configured${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- Prompts for GIT_USER_NAME if not configured${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- Sets up zsh completion in ~/.zshrc${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- Creates aliases (f-rebase, f-commit, f-push, etc.) in ~/.zshrc${RESET}"
    echo ""
    
    echo -e "${CYAN}fit help${RESET}"
    echo -e "${INDENT}${GRAY}Displays this help message with detailed information about all commands.${RESET}"
    echo ""
    
    echo -e "${TEAL}GLOBAL FLAGS:${RESET}"
    echo ""
    echo -e "${CYAN}-unsafe${RESET}"
    echo -e "${INDENT}${GRAY}Bypasses the safety check that prevents operations when there are no new commits${RESET}"
    echo -e "${INDENT}${GRAY}compared to origin/DEFAULT_BRANCH. Can be used with: commit, uncommit, push.${RESET}"
    echo ""
    
    echo -e "${TEAL}SAFETY CHECKS:${RESET}"
    echo ""
    echo -e "${INDENT}${GRAY}The check_origin() function verifies that the local branch has new commits${RESET}"
    echo -e "${INDENT}${GRAY}compared to origin/DEFAULT_BRANCH. It uses:${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git rev-parse HEAD${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git rev-parse origin/<DEFAULT_BRANCH>${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git merge-base --is-ancestor${RESET}"
    echo -e "${INDENT}${INDENT}${GRAY}- git rev-list --count${RESET}"
    echo ""
}

case "$COMMAND" in
    help)
        show_help
        ;;
    
    rebase)
        do_rebase "$ARG1"
        ;;

    branch)
        if [ -z "$ARG1" ]; then
            error "Usage: fit branch <branch-name>"
            exit 1
        fi
        action_with_spinner "Fetching All Remotes" git fetch --all --prune
        save_branch_cache
        action_with_spinner_and_output "Checking Out Branch" git checkout "$ARG1"
        ;;

    new-branch)
        if [ -z "$ARG1" ] || [ -z "$ARG2" ]; then
            error "Usage: fit new-branch <identificator> \"commit message\" [-id task_id]"
            error "Identificator must be one of: add, change, update, fix, refactor, remove"
            exit 1
        fi
        
        # Validate identificator
        case "$ARG1" in
            add|change|update|fix|refactor|remove)
                ;;
            *)
                error "Invalid identificator: $ARG1"
                error "Must be one of: add, change, update, fix, refactor, remove"
                exit 1
                ;;
        esac
        
        check_git_identity
        
        # Format branch name
        formatted_commit=$(format_commit_for_branch "$ARG2")
        if [ -n "$TASK_ID" ]; then
            branch_name="${TASK_ID}_${ARG1}-${formatted_commit}"
        else
            branch_name="${ARG1}-${formatted_commit}"
        fi
        
        # Format commit message
        past_tense=$(get_past_tense "$ARG1")
        commit_message="${past_tense} $ARG2"
        
        # Create and checkout new branch
        action_with_spinner_and_output "Creating New Branch" git checkout -b "$branch_name"
        
        # Create empty commit
        action_with_spinner_and_output "Creating Empty Commit" git commit --allow-empty -m "$commit_message"
        ;;

    log)
        show_log "$@"
        ;;

    stash)
        if [ -n "$ARG1" ]; then
            action_with_spinner_and_output "Stashing Changes" git stash push -m "$ARG1"
        else
            action_with_spinner_and_output "Stashing Changes" git stash push
        fi
        ;;

    stash-pop)
        selected_index=$(show_stash_list_and_select)
        if [ $? -ne 0 ]; then
            exit 0
        fi
        stash_ref="stash@{$selected_index}"
        action_with_spinner_and_output "Popping Stash" git stash pop "$stash_ref"
        ;;

    stash-apply)
        selected_index=$(show_stash_list_and_select)
        if [ $? -ne 0 ]; then
            exit 0
        fi
        stash_ref="stash@{$selected_index}"
        action_with_spinner_and_output "Applying Stash" git stash apply "$stash_ref"
        ;;

    stash-clear)
        stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
        if [ -z "$stash_count" ] || [ "$stash_count" -eq 0 ]; then
            info "No stashes found."
            exit 0
        fi
        
        echo ""
        echo -e "${TEAL}Warning: This will delete all $stash_count stash(es).${RESET}"
        echo -e "${TEAL}This action cannot be undone.${RESET}"
        echo ""
        echo -e "${TEAL}Are you sure you want to delete all stashes? (yes/no):${RESET} "
        read -r confirmation < /dev/tty
        
        if [ "$confirmation" != "yes" ]; then
            info "Operation cancelled."
            exit 0
        fi
        
        action_with_spinner_and_output "Clearing All Stashes" git stash clear
        info "All stashes have been deleted."
        ;;

    gh-reviews)
        if [ "$USE_GITHUB" != "true" ]; then
            error "GitHub integration is not enabled. Run 'fit setup' to enable it."
            exit 1
        fi
        
        if ! command -v gh >/dev/null 2>&1; then
            error "GitHub CLI (gh) is not installed."
            exit 1
        fi
        
        if ! gh auth status >/dev/null 2>&1; then
            error "Not authenticated with GitHub. Run 'gh auth login' or 'fit setup'."
            exit 1
        fi
        
        repo=$(git remote get-url origin 2>/dev/null | sed -E 's/.*github\.com[:/]([^/]+\/[^/]+)(\.git)?$/\1/' | sed 's/\.git$//')
        if [ -z "$repo" ]; then
            error "Could not determine GitHub repository. Make sure you're in a git repository with a GitHub remote."
            exit 1
        fi
        
        echo ""
        echo -e "${TEAL}Pull Request Reviews for: ${repo}${RESET}"
        echo ""
        
        branches=$(git branch -r --format='%(refname:short)' 2>/dev/null | sed 's|origin/||' | grep -v HEAD | sort -u)
        
        for branch in $branches; do
            pr_json=$(gh pr list --repo "$repo" --head "$branch" --json number,title,state,reviews 2>/dev/null)
            
            if [ -z "$pr_json" ] || [ "$pr_json" = "[]" ]; then
                continue
            fi
            
            pr_number=$(echo "$pr_json" | grep -o '"number":[0-9]*' | head -1 | cut -d':' -f2)
            pr_title=$(echo "$pr_json" | grep -o '"title":"[^"]*"' | head -1 | sed 's/"title":"\([^"]*\)"/\1/')
            
            if [ -z "$pr_number" ]; then
                continue
            fi
            
            reviews_json=$(gh pr view "$pr_number" --repo "$repo" --json reviews 2>/dev/null)
            
            review_state="pending"
            if echo "$reviews_json" | grep -q '"state":"APPROVED"'; then
                if ! echo "$reviews_json" | grep -q '"state":"CHANGES_REQUESTED"'; then
                    review_state="approved"
                fi
            fi
            if echo "$reviews_json" | grep -q '"state":"CHANGES_REQUESTED"'; then
                review_state="changes requested"
            fi
            
            echo -e "${INDENT}${CYAN}$branch${RESET}"
            if [ -n "$pr_title" ]; then
                echo -e "${INDENT}${INDENT}${GRAY}PR #$pr_number: $pr_title${RESET}"
            else
                echo -e "${INDENT}${INDENT}${GRAY}PR #$pr_number${RESET}"
            fi
            case "$review_state" in
                approved)
                    echo -e "${INDENT}${INDENT}${YELLOW}Review State:${RESET} ${GRAY}approved${RESET}"
                    ;;
                "changes requested")
                    echo -e "${INDENT}${INDENT}${YELLOW}Review State:${RESET} ${RED}changes requested${RESET}"
                    ;;
                *)
                    echo -e "${INDENT}${INDENT}${YELLOW}Review State:${RESET} ${GRAY}pending${RESET}"
                    ;;
            esac
            echo ""
        done
        ;;

    gh-checks)
        if [ "$USE_GITHUB" != "true" ]; then
            error "GitHub integration is not enabled. Run 'fit setup' to enable it."
            exit 1
        fi
        
        if ! command -v gh >/dev/null 2>&1; then
            error "GitHub CLI (gh) is not installed."
            exit 1
        fi
        
        if ! gh auth status >/dev/null 2>&1; then
            error "Not authenticated with GitHub. Run 'gh auth login' or 'fit setup'."
            exit 1
        fi
        
        repo=$(git remote get-url origin 2>/dev/null | sed -E 's/.*github\.com[:/]([^/]+\/[^/]+)(\.git)?$/\1/' | sed 's/\.git$//')
        if [ -z "$repo" ]; then
            error "Could not determine GitHub repository. Make sure you're in a git repository with a GitHub remote."
            exit 1
        fi
        
        echo ""
        echo -e "${TEAL}CI Checks Status for: ${repo}${RESET}"
        echo ""
        
        branches=$(git branch -r --format='%(refname:short)' 2>/dev/null | sed 's|origin/||' | grep -v HEAD | sort -u)
        
        for branch in $branches; do
            pr_json=$(gh pr list --repo "$repo" --head "$branch" --json number,title,state 2>/dev/null)
            
            if [ -z "$pr_json" ] || [ "$pr_json" = "[]" ]; then
                continue
            fi
            
            pr_number=$(echo "$pr_json" | grep -o '"number":[0-9]*' | head -1 | cut -d':' -f2)
            pr_title=$(echo "$pr_json" | grep -o '"title":"[^"]*"' | head -1 | sed 's/"title":"\([^"]*\)"/\1/')
            
            if [ -z "$pr_number" ]; then
                continue
            fi
            
            checks_json=$(gh pr checks "$pr_number" --repo "$repo" --json name,state,bucket 2>/dev/null)
            
            if [ -z "$checks_json" ] || [ "$checks_json" = "[]" ]; then
                continue
            fi
            
            echo -e "${INDENT}${CYAN}$branch${RESET}"
            if [ -n "$pr_title" ]; then
                echo -e "${INDENT}${INDENT}${GRAY}PR #$pr_number: $pr_title${RESET}"
            else
                echo -e "${INDENT}${INDENT}${GRAY}PR #$pr_number${RESET}"
            fi
            
            if command -v jq >/dev/null 2>&1; then
                check_count=$(echo "$checks_json" | jq 'length' 2>/dev/null || echo "0")
                if [ "$check_count" = "0" ]; then
                    echo -e "${INDENT}${INDENT}${YELLOW}Checks:${RESET} ${GRAY}No checks found${RESET}"
                else
                    pass_count=$(echo "$checks_json" | jq '[.[] | select(.bucket == "pass")] | length' 2>/dev/null || echo "0")
                    fail_count=$(echo "$checks_json" | jq '[.[] | select(.bucket == "fail")] | length' 2>/dev/null || echo "0")
                    pending_count=$(echo "$checks_json" | jq '[.[] | select(.bucket == "pending")] | length' 2>/dev/null || echo "0")
                    
                    if [ "$fail_count" -gt 0 ]; then
                        echo -e "${INDENT}${INDENT}${YELLOW}Checks:${RESET} ${RED}failed ($fail_count)${RESET}"
                    elif [ "$pending_count" -gt 0 ]; then
                        echo -e "${INDENT}${INDENT}${YELLOW}Checks:${RESET} ${YELLOW}pending ($pending_count)${RESET}"
                    elif [ "$pass_count" -eq "$check_count" ]; then
                        echo -e "${INDENT}${INDENT}${YELLOW}Checks:${RESET} ${GRAY}passed ($pass_count/$check_count)${RESET}"
                    else
                        echo -e "${INDENT}${INDENT}${YELLOW}Checks:${RESET} ${GRAY}partial ($pass_count/$check_count)${RESET}"
                    fi
                fi
            else
                check_lines=$(echo "$checks_json" | grep -c '"name"' 2>/dev/null || echo "0")
                if [ "$check_lines" -eq 0 ]; then
                    echo -e "${INDENT}${INDENT}${YELLOW}Checks:${RESET} ${GRAY}No checks found${RESET}"
                else
                    pass_count=$(echo "$checks_json" | grep -o '"bucket":"pass"' | wc -l)
                    fail_count=$(echo "$checks_json" | grep -o '"bucket":"fail"' | wc -l)
                    pending_count=$(echo "$checks_json" | grep -o '"bucket":"pending"' | wc -l)
                    
                    if [ "$fail_count" -gt 0 ]; then
                        echo -e "${INDENT}${INDENT}${YELLOW}Checks:${RESET} ${RED}failed ($fail_count)${RESET}"
                    elif [ "$pending_count" -gt 0 ]; then
                        echo -e "${INDENT}${INDENT}${YELLOW}Checks:${RESET} ${YELLOW}pending ($pending_count)${RESET}"
                    elif [ "$pass_count" -eq "$check_lines" ]; then
                        echo -e "${INDENT}${INDENT}${YELLOW}Checks:${RESET} ${GRAY}passed ($pass_count/$check_lines)${RESET}"
                    else
                        echo -e "${INDENT}${INDENT}${YELLOW}Checks:${RESET} ${GRAY}partial ($pass_count/$check_lines)${RESET}"
                    fi
                fi
            fi
            echo ""
        done
        ;;

    check-unsafe)
        error "ERROR: This command has been disabled."
        exit 1
        ;;

    commit)
        check_git_identity
        do_commit "$ARG1"
        ;;

    uncommit)
        check_origin
        action_with_spinner_and_output "Removing Last Commit (soft reset)" git reset --soft HEAD~1
        info "Last commit removed. Changes are preserved in staging area."
        ;;

    push)
        check_git_identity
        
        # 1. Commit/Amend
        do_commit "$ARG1"

        # 2. Rebase
        do_rebase
        
        # 3. Check if rebase was successful
        if [ $? -eq 0 ]; then
            current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
            if [ -n "$current_branch" ]; then
                action_with_spinner_and_output "Force Pushing" git push --force --set-upstream origin "$current_branch"
            else
                action_with_spinner_and_output "Force Pushing" git push --force
            fi
        else
            error "ERROR: Conflicts detected during rebase! Push aborted. Please resolve conflicts and push manually."
            exit 1
        fi
        ;;

    setup)
        CONFIG_FILE="$FIT_CONFIG"
        ZSHRC="$HOME/.zshrc"
        
        source "$CONFIG_FILE"
        DEFAULT_BRANCH=$(echo "$DEFAULT_BRANCH" | tr -d '\r' | xargs)
        GIT_USER_EMAIL=$(echo "$GIT_USER_EMAIL" | tr -d '\r' | xargs)
        GIT_USER_NAME=$(echo "$GIT_USER_NAME" | tr -d '\r' | xargs)
        USE_GITHUB=$(echo "$USE_GITHUB" | tr -d '\r' | xargs)
        
        if [ -z "$DEFAULT_BRANCH" ]; then
            echo ""
            echo -e "${INDENT}${TEAL}Setting Up Default Branch${RESET}"
            read -p "Enter your default branch name (e.g., master, main): " DEFAULT_BRANCH
            if [ -z "$DEFAULT_BRANCH" ]; then
                error "Error: Default branch is required."
                exit 1
            fi
            if ! grep -q "^DEFAULT_BRANCH=" "$CONFIG_FILE" 2>/dev/null; then
                echo "DEFAULT_BRANCH=\"$DEFAULT_BRANCH\"" >> "$CONFIG_FILE"
            else
                sed -i "s|^DEFAULT_BRANCH=.*|DEFAULT_BRANCH=\"$DEFAULT_BRANCH\"|" "$CONFIG_FILE"
            fi
            info "Default branch saved to config."
            action "Setting Up Default Branch"
        else
            info "Default branch already configured: $DEFAULT_BRANCH"
        fi
        
        if [ -z "$GIT_USER_EMAIL" ] || [ -z "$GIT_USER_NAME" ]; then
            echo ""
            echo -e "${INDENT}${TEAL}Setting Up Git Identity${RESET}"
            
            if [ -z "$GIT_USER_EMAIL" ]; then
                read -p "Enter your git email: " GIT_USER_EMAIL
                if [ -z "$GIT_USER_EMAIL" ]; then
                    error "Error: Email is required."
                    exit 1
                fi
                if ! grep -q "^GIT_USER_EMAIL=" "$CONFIG_FILE" 2>/dev/null; then
                    echo "GIT_USER_EMAIL=\"$GIT_USER_EMAIL\"" >> "$CONFIG_FILE"
                else
                    sed -i "s|^GIT_USER_EMAIL=.*|GIT_USER_EMAIL=\"$GIT_USER_EMAIL\"|" "$CONFIG_FILE"
                fi
            fi
            
            if [ -z "$GIT_USER_NAME" ]; then
                read -p "Enter your git name: " GIT_USER_NAME
                if [ -z "$GIT_USER_NAME" ]; then
                    error "Error: Name is required."
                    exit 1
                fi
                if ! grep -q "^GIT_USER_NAME=" "$CONFIG_FILE" 2>/dev/null; then
                    echo "GIT_USER_NAME=\"$GIT_USER_NAME\"" >> "$CONFIG_FILE"
                else
                    sed -i "s|^GIT_USER_NAME=.*|GIT_USER_NAME=\"$GIT_USER_NAME\"|" "$CONFIG_FILE"
                fi
            fi
            
            info "Git identity saved to config."
            action "Setting Up Git Identity"
        else
            info "Git identity already configured."
        fi
        
        if [ "$USE_GITHUB" != "true" ]; then
            echo ""
            read -p "Do you want to connect your GitHub account? (yes/no): " connect_github
            if [ "$connect_github" = "yes" ] || [ "$connect_github" = "y" ]; then
                echo ""
                echo -e "${INDENT}${TEAL}Setting Up GitHub${RESET}"
                
                if ! command -v gh >/dev/null 2>&1; then
                    info "GitHub CLI not found. Installing..."
                    if command -v brew >/dev/null 2>&1; then
                        action_with_spinner_and_output "Installing GitHub CLI" brew install gh
                        hash -r
                    elif command -v apt-get >/dev/null 2>&1; then
                        if [ "$(id -u)" -eq 0 ]; then
                            if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
                                info "Adding GitHub CLI repository..."
                                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
                                chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
                                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                            fi
                            install_output=$(mktemp)
                            action_start "Installing GitHub CLI"
                            if apt-get update > "$install_output" 2>&1 && apt-get install -y gh >> "$install_output" 2>&1; then
                                action_end "Installing GitHub CLI"
                                while IFS= read -r line || [ -n "$line" ]; do
                                    [ -n "$line" ] && info "$line"
                                done < "$install_output"
                                rm -f "$install_output"
                            else
                                action_end "Installing GitHub CLI"
                                error "Installation failed. Output:"
                                while IFS= read -r line || [ -n "$line" ]; do
                                    [ -n "$line" ] && error "$line"
                                done < "$install_output"
                                rm -f "$install_output"
                                error "Please install GitHub CLI manually: https://cli.github.com/"
                                exit 1
                            fi
                        else
                            info "Sudo access is required to install GitHub CLI. You may be prompted for your password."
                            if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
                                info "Adding GitHub CLI repository..."
                                if ! curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null; then
                                    error "Failed to add GitHub CLI repository key."
                                    exit 1
                                fi
                                sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
                                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                            fi
                            install_output=$(mktemp)
                            action_start "Installing GitHub CLI"
                            if sudo apt-get update > "$install_output" 2>&1 && sudo apt-get install -y gh >> "$install_output" 2>&1; then
                                action_end "Installing GitHub CLI"
                                while IFS= read -r line || [ -n "$line" ]; do
                                    [ -n "$line" ] && info "$line"
                                done < "$install_output"
                                rm -f "$install_output"
                            else
                                action_end "Installing GitHub CLI"
                                error "Installation failed. Output:"
                                while IFS= read -r line || [ -n "$line" ]; do
                                    [ -n "$line" ] && error "$line"
                                done < "$install_output"
                                rm -f "$install_output"
                                error "Please run: sudo fit setup"
                                error "Or install GitHub CLI manually: https://cli.github.com/"
                                exit 1
                            fi
                        fi
                        hash -r
                        if ! command -v gh >/dev/null 2>&1; then
                            for gh_path in /usr/bin/gh /usr/local/bin/gh /snap/bin/gh; do
                                if [ -f "$gh_path" ] && [ -x "$gh_path" ]; then
                                    export PATH="$(dirname "$gh_path"):$PATH"
                                    break
                                fi
                            done
                            if ! command -v gh >/dev/null 2>&1 && dpkg -l | grep -q "^ii.*gh "; then
                                info "GitHub CLI package is installed. Trying to locate binary..."
                                gh_location=$(dpkg -L gh 2>/dev/null | grep -E '/bin/gh$' | head -1)
                                if [ -n "$gh_location" ] && [ -x "$gh_location" ]; then
                                    export PATH="$(dirname "$gh_location"):$PATH"
                                fi
                            fi
                        fi
                    elif command -v yum >/dev/null 2>&1; then
                        if [ "$(id -u)" -eq 0 ]; then
                            action_with_spinner_and_output "Installing GitHub CLI" yum install -y gh
                        else
                            info "Sudo access is required to install GitHub CLI. You may be prompted for your password."
                            if ! action_with_spinner_and_output "Installing GitHub CLI" sudo yum install -y gh; then
                                error "Installation failed. If you were prompted for a password, please run: sudo fit setup"
                                error "Or install GitHub CLI manually: https://cli.github.com/"
                                exit 1
                            fi
                        fi
                        hash -r
                        if ! command -v gh >/dev/null 2>&1 && [ -f /usr/bin/gh ]; then
                            export PATH="/usr/bin:$PATH"
                        fi
                    else
                        error "Could not detect package manager. Please install GitHub CLI manually: https://cli.github.com/"
                        exit 1
                    fi
                    
                    if ! command -v gh >/dev/null 2>&1; then
                        error "GitHub CLI was installed but cannot be found. Please restart your terminal and run 'fit setup' again."
                        exit 1
                    fi
                fi
                
                if gh auth status >/dev/null 2>&1; then
                    info "GitHub is already authenticated."
                    USE_GITHUB="true"
                else
                    info "Logging in to GitHub..."
                    if gh auth login; then
                        USE_GITHUB="true"
                        info "GitHub authentication successful."
                    else
                        error "GitHub authentication failed."
                        USE_GITHUB="false"
                    fi
                fi
                
                if ! grep -q "^USE_GITHUB=" "$CONFIG_FILE" 2>/dev/null; then
                    echo "USE_GITHUB=\"$USE_GITHUB\"" >> "$CONFIG_FILE"
                else
                    sed -i "s|^USE_GITHUB=.*|USE_GITHUB=\"$USE_GITHUB\"|" "$CONFIG_FILE"
                fi
                
                action "Setting Up GitHub"
            else
                USE_GITHUB="false"
                if ! grep -q "^USE_GITHUB=" "$CONFIG_FILE" 2>/dev/null; then
                    echo "USE_GITHUB=\"false\"" >> "$CONFIG_FILE"
                else
                    sed -i "s|^USE_GITHUB=.*|USE_GITHUB=\"false\"|" "$CONFIG_FILE"
                fi
                info "GitHub integration skipped."
            fi
        else
            if ! command -v gh >/dev/null 2>&1; then
                error "GitHub CLI (gh) is not installed."
                exit 1
            fi
            
            if gh auth status >/dev/null 2>&1; then
                info "GitHub is already connected."
            else
                info "GitHub was configured but authentication is missing. Re-authenticating..."
                if gh auth login; then
                    info "GitHub re-authentication successful."
                else
                    error "GitHub re-authentication failed. Run 'fit setup' again to fix."
                fi
            fi
        fi
        
        if [ ! -f "$ZSHRC" ]; then
            info "Warning: ~/.zshrc not found. Skipping zsh completion and alias setup."
        else
            if grep -q "fit completion" "$ZSHRC"; then
                sed -i '/# fit completion/d' "$ZSHRC"
                sed -i '/fpath=.*\.fit/d' "$ZSHRC"
                sed -i '/autoload -Uz compinit && compinit/d' "$ZSHRC"
                sed -i '/fit quick completion/d' "$ZSHRC"
                sed -i '/compdef _fit fit/d' "$ZSHRC"
                sed -i '/expand-f-to-fit/d' "$ZSHRC"
                sed -i '/bindkey.*expand-f-to-fit/d' "$ZSHRC"
                info "Removed existing zsh completion configuration."
            fi
            
            if grep -q "# fit aliases" "$ZSHRC"; then
                sed -i '/# fit aliases/,/# end fit aliases/d' "$ZSHRC"
                info "Removed existing fit aliases."
            fi
            
            echo "" >> "$ZSHRC"
            echo "# fit completion" >> "$ZSHRC"
            echo "fpath=($FIT_DIR \$fpath)" >> "$ZSHRC"
            echo "autoload -Uz compinit && compinit" >> "$ZSHRC"
            echo "" >> "$ZSHRC"
            echo "# fit completion" >> "$ZSHRC"
            echo "compdef _fit fit" >> "$ZSHRC"
            
            echo "" >> "$ZSHRC"
            echo "# fit aliases" >> "$ZSHRC"
            
            SCRIPT_PATH="$FIT_DIR/fit.sh"
            if [ ! -f "$SCRIPT_PATH" ]; then
                SCRIPT_PATH="$0"
                if [ -L "$SCRIPT_PATH" ]; then
                    SCRIPT_PATH=$(readlink -f "$SCRIPT_PATH" 2>/dev/null || readlink "$SCRIPT_PATH" 2>/dev/null || echo "$SCRIPT_PATH")
                fi
            fi
            
            if [ -f "$SCRIPT_PATH" ]; then
                BLACKLIST="setup check-unsafe"
                commands=$(sed -n '/^case "\$COMMAND" in$/,/^esac$/p' "$SCRIPT_PATH" 2>/dev/null | grep -E '^[[:space:]]+[a-z][a-z-]*\)' | sed 's/^[[:space:]]*\([a-z][a-z-]*\)).*/\1/' | sort -u)
                
                for cmd in $commands; do
                    if [ -n "$cmd" ]; then
                        is_blacklisted=false
                        for blacklisted in $BLACKLIST; do
                            if [ "$cmd" = "$blacklisted" ]; then
                                is_blacklisted=true
                                break
                            fi
                        done
                        
                        if [ "$is_blacklisted" = "false" ]; then
                            alias_name="f-${cmd}"
                            echo "alias ${alias_name}='fit ${cmd}'" >> "$ZSHRC"
                        fi
                    fi
                done
            fi
            
            echo "# end fit aliases" >> "$ZSHRC"
            
            info "Zsh completion and aliases for fit have been updated in ~/.zshrc"
            info "Run 'source ~/.zshrc' or restart your terminal to enable them."
        fi
        
        action "Setup Complete"
        ;;

    *)
        info "Usage: fit {rebase|commit|uncommit|push|log|branch|new-branch|setup|help} [arg] [-unsafe]"
        info "Run 'fit help' for detailed information about all commands."
        ;;
esac
