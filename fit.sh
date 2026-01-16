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

case "$COMMAND" in
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

    check-unsafe)
        if [ "$ARG1" = "origin" ]; then
            check_origin
            if [ $? -eq 0 ]; then
                info "Check passed: Local branch has new commits compared to origin/$DEFAULT_BRANCH"
            fi
        else
            error "Usage: fit check-unsafe origin"
        fi
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
        
        if [ -z "$DEFAULT_BRANCH" ]; then
            action_start "Setting Up Default Branch"
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
            action_end "Setting Up Default Branch"
        else
            info "Default branch already configured: $DEFAULT_BRANCH"
        fi
        
        if [ -z "$GIT_USER_EMAIL" ] || [ -z "$GIT_USER_NAME" ]; then
            action_start "Setting Up Git Identity"
            
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
            action_end "Setting Up Git Identity"
        else
            info "Git identity already configured."
        fi
        
        if [ ! -f "$ZSHRC" ]; then
            info "Warning: ~/.zshrc not found. Skipping zsh completion setup."
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
            
            echo "" >> "$ZSHRC"
            echo "# fit completion" >> "$ZSHRC"
            echo "fpath=($FIT_DIR \$fpath)" >> "$ZSHRC"
            echo "autoload -Uz compinit && compinit" >> "$ZSHRC"
            echo "" >> "$ZSHRC"
            echo "# fit completion" >> "$ZSHRC"
            echo "compdef _fit fit" >> "$ZSHRC"
            
            info "Zsh completion for fit has been updated in ~/.zshrc"
            info "Run 'source ~/.zshrc' or restart your terminal to enable it."
        fi
        
        action "Setup Complete"
        ;;

    *)
        info "Usage: fit {rebase|commit|uncommit|push|log|branch|new-branch|check-unsafe|setup} [arg] [-unsafe]"
        ;;
esac
