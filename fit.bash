_fit() {
    local cur prev words cword
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
    
    local config_file=""
    local use_github="false"
    
    if command -v brew >/dev/null 2>&1; then
        local brew_prefix=$(brew --prefix 2>/dev/null)
        if [ -n "$brew_prefix" ] && [ -f "$brew_prefix/opt/fit/config" ]; then
            config_file="$brew_prefix/opt/fit/config"
        fi
    fi
    if [ -z "$config_file" ] && [ -f "$HOME/.fit/config" ]; then
        config_file="$HOME/.fit/config"
    fi
    
    if [ -n "$config_file" ] && [ -f "$config_file" ]; then
        source "$config_file" 2>/dev/null
        use_github=$(echo "$USE_GITHUB" | tr -d '\r' | xargs)
    fi
    
    local commands="rebase commit uncommit push log branch new-branch stash stash-pop stash-apply stash-clear setup help"
    
    if [ "$use_github" = "true" ]; then
        commands="$commands gh-reviews gh-checks"
    fi
    
    case $cword in
        1)
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            ;;
        *)
            case "${words[1]}" in
                rebase)
                    if [ $cword -eq 2 ]; then
                        if command -v git >/dev/null 2>&1; then
                            local branches
                            branches=$(git branch -r --format='%(refname:short)' 2>/dev/null | sed 's|origin/||' | sort -u | tr '\n' ' ')
                            COMPREPLY=($(compgen -W "$branches" -- "$cur"))
                        fi
                    fi
                    ;;
                branch)
                    if [ $cword -eq 2 ]; then
                        local cache_file=""
                        if command -v brew >/dev/null 2>&1; then
                            local brew_prefix=$(brew --prefix 2>/dev/null)
                            if [ -n "$brew_prefix" ] && [ -f "$brew_prefix/opt/fit/.branch_cache" ]; then
                                cache_file="$brew_prefix/opt/fit/.branch_cache"
                            fi
                        fi
                        if [ -z "$cache_file" ] && [ -f "$HOME/.fit/.branch_cache" ]; then
                            cache_file="$HOME/.fit/.branch_cache"
                        fi
                        if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
                            local branches
                            branches=$(cat "$cache_file" 2>/dev/null | tr '\n' ' ')
                            COMPREPLY=($(compgen -W "$branches" -- "$cur"))
                        elif command -v git >/dev/null 2>&1; then
                            local branches
                            branches=$(git branch -r --format='%(refname:short)' 2>/dev/null | sed 's|origin/||' | sort -u | tr '\n' ' ')
                            COMPREPLY=($(compgen -W "$branches" -- "$cur"))
                        fi
                    fi
                    ;;
                new-branch)
                    if [ $cword -eq 2 ]; then
                        local identificators="add change update fix refactor remove"
                        COMPREPLY=($(compgen -W "$identificators" -- "$cur"))
                    elif [ $cword -eq 3 ]; then
                        if [[ "$cur" == -* ]]; then
                            COMPREPLY=($(compgen -W "-id" -- "$cur"))
                        fi
                    elif [ $cword -eq 4 ] && [ "${words[3]}" = "-id" ]; then
                        COMPREPLY=()
                    fi
                    ;;
                commit|push|stash|uncommit)
                    if [[ "$cur" == -* ]]; then
                        local has_unsafe=false
                        for word in "${words[@]}"; do
                            if [ "$word" = "-unsafe" ]; then
                                has_unsafe=true
                                break
                            fi
                        done
                        if [ "$has_unsafe" = "false" ]; then
                            COMPREPLY=($(compgen -W "-unsafe" -- "$cur"))
                        fi
                    fi
                    ;;
                stash-pop|stash-apply|stash-clear|gh-reviews|gh-checks|log|setup|help)
                    ;;
            esac
            ;;
    esac
    
    return 0
}

_fit_alias() {
    local cur prev words cword
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
    
    local alias_cmd="${COMP_WORDS[0]}"
    local fit_cmd="${alias_cmd#f-}"
    
    words[1]="$fit_cmd"
    
    local config_file=""
    local use_github="false"
    
    if command -v brew >/dev/null 2>&1; then
        local brew_prefix=$(brew --prefix 2>/dev/null)
        if [ -n "$brew_prefix" ] && [ -f "$brew_prefix/opt/fit/config" ]; then
            config_file="$brew_prefix/opt/fit/config"
        fi
    fi
    if [ -z "$config_file" ] && [ -f "$HOME/.fit/config" ]; then
        config_file="$HOME/.fit/config"
    fi
    
    if [ -n "$config_file" ] && [ -f "$config_file" ]; then
        source "$config_file" 2>/dev/null
        use_github=$(echo "$USE_GITHUB" | tr -d '\r' | xargs)
    fi
    
    case $cword in
        1)
            COMPREPLY=()
            ;;
        *)
            case "$fit_cmd" in
                rebase)
                    if [ $cword -eq 2 ]; then
                        if command -v git >/dev/null 2>&1; then
                            local branches
                            branches=$(git branch -r --format='%(refname:short)' 2>/dev/null | sed 's|origin/||' | sort -u | tr '\n' ' ')
                            COMPREPLY=($(compgen -W "$branches" -- "$cur"))
                        fi
                    fi
                    ;;
                branch)
                    if [ $cword -eq 2 ]; then
                        local cache_file=""
                        if command -v brew >/dev/null 2>&1; then
                            local brew_prefix=$(brew --prefix 2>/dev/null)
                            if [ -n "$brew_prefix" ] && [ -f "$brew_prefix/opt/fit/.branch_cache" ]; then
                                cache_file="$brew_prefix/opt/fit/.branch_cache"
                            fi
                        fi
                        if [ -z "$cache_file" ] && [ -f "$HOME/.fit/.branch_cache" ]; then
                            cache_file="$HOME/.fit/.branch_cache"
                        fi
                        if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
                            local branches
                            branches=$(cat "$cache_file" 2>/dev/null | tr '\n' ' ')
                            COMPREPLY=($(compgen -W "$branches" -- "$cur"))
                        elif command -v git >/dev/null 2>&1; then
                            local branches
                            branches=$(git branch -r --format='%(refname:short)' 2>/dev/null | sed 's|origin/||' | sort -u | tr '\n' ' ')
                            COMPREPLY=($(compgen -W "$branches" -- "$cur"))
                        fi
                    fi
                    ;;
                new-branch)
                    if [ $cword -eq 2 ]; then
                        local identificators="add change update fix refactor remove"
                        COMPREPLY=($(compgen -W "$identificators" -- "$cur"))
                    elif [ $cword -eq 3 ]; then
                        if [[ "$cur" == -* ]]; then
                            COMPREPLY=($(compgen -W "-id" -- "$cur"))
                        fi
                    elif [ $cword -eq 4 ] && [ "${words[3]}" = "-id" ]; then
                        COMPREPLY=()
                    fi
                    ;;
                commit|push|stash|uncommit)
                    if [[ "$cur" == -* ]]; then
                        local has_unsafe=false
                        for word in "${words[@]}"; do
                            if [ "$word" = "-unsafe" ]; then
                                has_unsafe=true
                                break
                            fi
                        done
                        if [ "$has_unsafe" = "false" ]; then
                            COMPREPLY=($(compgen -W "-unsafe" -- "$cur"))
                        fi
                    fi
                    ;;
            esac
            ;;
    esac
    
    return 0
}

complete -F _fit fit

if command -v fit >/dev/null 2>&1; then
    fit_dir=""
    if command -v brew >/dev/null 2>&1; then
        brew_prefix=$(brew --prefix 2>/dev/null)
        if [ -n "$brew_prefix" ] && [ -f "$brew_prefix/opt/fit/fit.sh" ]; then
            fit_dir="$brew_prefix/opt/fit"
        fi
    fi
    if [ -z "$fit_dir" ] && [ -f "$HOME/.fit/fit.sh" ]; then
        fit_dir="$HOME/.fit"
    fi
    
    if [ -n "$fit_dir" ] && [ -f "$fit_dir/fit.sh" ]; then
        blacklist="setup check-unsafe approved"
        commands=$(sed -n '/^case "\$COMMAND" in$/,/^esac$/p' "$fit_dir/fit.sh" 2>/dev/null | grep -E '^[[:space:]]+[a-z][a-z-]*\)' | sed 's/^[[:space:]]*\([a-z][a-z-]*\)).*/\1/' | sort -u)
        
        for cmd in $commands; do
            is_blacklisted=false
            for blacklisted in $blacklist; do
                if [ "$cmd" = "$blacklisted" ]; then
                    is_blacklisted=true
                    break
                fi
            done
            
            if [ "$is_blacklisted" = "false" ]; then
                alias_name="f-${cmd}"
                complete -F _fit_alias "$alias_name" 2>/dev/null
            fi
        done
    fi
fi
