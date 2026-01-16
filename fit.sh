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
        [ -n "$line" ] && info "$line"
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
if [[ -f "$(brew --prefix)/opt/fit/config" 2>/dev/null ]]; then
    FIT_DIR="$(brew --prefix)/opt/fit"
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

for arg in "$@"; do
    if [ "$arg" = "-unsafe" ]; then
        UNSAFE_FLAG=true
        break
    fi
done

ARG1=""
ARG2=""
shift
for arg in "$@"; do
    if [ "$arg" != "-unsafe" ]; then
        if [ -z "$ARG1" ]; then
            ARG1="$arg"
        elif [ -z "$ARG2" ]; then
            ARG2="$arg"
        fi
    fi
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
do_rebase() {
    local target=${1:-$DEFAULT_BRANCH}
    action_with_spinner "Syncing with origin/$target" git fetch --all --prune
    action_with_spinner_and_output "Rebasing with origin/$target" git rebase "origin/$target"
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
        if [ -z "$ARG1" ]; then
            check_origin
            action_with_spinner_and_output "Amending Commit" git commit --amend --no-edit --allow-empty
        else
            action_with_spinner_and_output "Creating New Commit" git commit -m "$ARG1" --allow-empty
        fi
        ;;

    uncommit)
        check_origin
        action_with_spinner_and_output "Removing Last Commit (soft reset)" git reset --soft HEAD~1
        info "Last commit removed. Changes are preserved in staging area."
        ;;

    push)
        check_git_identity
        
        # 1. Commit/Amend
        if [ -z "$ARG1" ]; then
            check_origin
            action_with_spinner_and_output "Amending Commit" git commit --amend --no-edit --allow-empty
        else
            action_with_spinner_and_output "Creating New Commit" git commit -m "$ARG1" --allow-empty
        fi

        # 2. Rebase
        do_rebase
        
        # 3. Check if rebase was successful
        if [ $? -eq 0 ]; then
            action_with_spinner_and_output "Force Pushing" git push --force
        else
            error "ERROR: Conflicts detected during rebase! Push aborted. Please resolve conflicts and push manually."
            exit 1
        fi
        ;;

    setup)
        CONFIG_FILE="$FIT_CONFIG"
        ZSHRC="$HOME/.zshrc"
        
        source "$CONFIG_FILE"
        GIT_USER_EMAIL=$(echo "$GIT_USER_EMAIL" | tr -d '\r' | xargs)
        GIT_USER_NAME=$(echo "$GIT_USER_NAME" | tr -d '\r' | xargs)
        
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
            echo "# fit quick completion - type 'f' + Tab to expand to 'fit '" >> "$ZSHRC"
            echo "compdef _fit fit" >> "$ZSHRC"
            echo "expand-f-to-fit() {" >> "$ZSHRC"
            echo "  if [[ \"\$BUFFER\" == \"f\" ]] || [[ \"\$BUFFER\" == \"f \" ]]; then" >> "$ZSHRC"
            echo "    BUFFER=\"fit \"" >> "$ZSHRC"
            echo "    CURSOR=4" >> "$ZSHRC"
            echo "  else" >> "$ZSHRC"
            echo "    zle expand-or-complete" >> "$ZSHRC"
            echo "  fi" >> "$ZSHRC"
            echo "}" >> "$ZSHRC"
            echo "[[ -t 0 ]] && { zle -N expand-f-to-fit 2>/dev/null && bindkey '^I' expand-f-to-fit 2>/dev/null; } || true" >> "$ZSHRC"
            
            info "Zsh completion for fit has been updated in ~/.zshrc"
            info "Run 'source ~/.zshrc' or restart your terminal to enable it."
        fi
        
        action "Setup Complete"
        ;;

    *)
        info "Usage: fit {rebase|commit|uncommit|push|log|check-unsafe|setup} [arg] [-unsafe]"
        ;;
esac
