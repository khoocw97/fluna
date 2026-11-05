# Manage starship prompt and zoxide in ~/.bashrc. Options: status | enable | disable
setup-shell ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    RC="$HOME/.bashrc"
    STARSHIP_LINE='eval "$(starship init bash)"'
    ZOXIDE_LINE='eval "$(zoxide init bash)"'
    get_status_token() {
        if grep -qF 'starship init' "$RC" 2>/dev/null; then
            echo "enable"
        else
            echo "disable"
        fi
    }
    get_current_status() {
        if [[ "$(get_status_token)" == "enable" ]]; then
            echo "Enabled"
        else
            echo "Not Enabled"
        fi
    }
    toggle_lines() {
        local marker="$1" action="$2"
        shift 2
        sed -i -e "/^# $marker$/d" "$RC"
        for line in "$@"; do
            grep -Fxv -- "$line" "$RC" > "$RC.tmp" && mv "$RC.tmp" "$RC"
        done
        if [[ "$action" == "enable" ]]; then
            printf '\n# %s\n' "$marker" >> "$RC"
            for line in "$@"; do
                printf '%s\n' "$line" >> "$RC"
            done
        fi
    }
    enable_starship() {
        if grep -qFx "$STARSHIP_LINE" "$RC"; then
            echo "Starship already enabled, skipped"
        else
            toggle_lines "starship prompt" enable "$STARSHIP_LINE"
            echo "Starship enabled, reopen terminal"
        fi
    }
    enable_zoxide() {
        if grep -qFx "$ZOXIDE_LINE" "$RC"; then
            echo "Zoxide already enabled, skipped"
        else
            toggle_lines "zoxide init" enable "$ZOXIDE_LINE"
            echo "Zoxide enabled, reopen terminal"
        fi
    }
    enable_aliases() {
        if grep -qF 'alias ll=' "$RC"; then
            echo "Aliases already enabled, skipped"
        else
            toggle_lines "eza & bat aliases" enable "${ALIASES[@]}"
            echo "Aliases enabled, reopen terminal"
        fi
    }
    disable_starship() {
        toggle_lines "starship prompt" disable "$STARSHIP_LINE"
        echo "Starship disabled, reopen terminal"
    }
    disable_zoxide() {
        toggle_lines "zoxide init" disable "$ZOXIDE_LINE"
        echo "Zoxide disabled, reopen terminal"
    }
    disable_aliases() {
        toggle_lines "eza & bat aliases" disable "${ALIASES[@]}"
        echo "Aliases disabled, reopen terminal"
    }
    ALIASES=(
        "alias ll='eza -l --icons=auto --group-directories-first'"
        "alias l.='eza -d .*'"
        "alias ls='eza'"
        "alias l1='eza -1'"
        "alias cat='bat --style=plain --pager=never'"
        # personal
        "alias lsblk='lsblk | bat -l conf -p'"
        "alias mv='mv -i'"
        "alias rm='rm -Iv'"
        "alias df='df -h'"
    )
    OPTION="{{ ACTION }}"
    if [[ "$OPTION" == "help" ]]; then
        echo "Usage: ujust setup-shell <option>"
        echo "  <option>: Specify the quick option to skip the prompt"
        echo "  Use 'status' to print the current status token"
        echo "  Use 'enable' to enable starship, zoxide and eza/bat aliases in ~/.bashrc"
        echo "  Use 'disable' to disable starship, zoxide and eza/bat aliases in ~/.bashrc"
        exit 0
    elif [[ "$OPTION" == "status" ]]; then
        get_status_token
        exit $?
    elif [[ "$OPTION" == "enable" ]]; then
        enable_starship
        enable_zoxide
        enable_aliases
        exit 0
    elif [[ "$OPTION" == "disable" ]]; then
        disable_starship
        disable_zoxide
        disable_aliases
        exit 0
    elif [[ -z "$OPTION" ]]; then
        current_status=$(get_current_status)
        echo "${bold}Starship & Zoxide & Aliases${normal}"
        echo "Current status: $current_status"
        OPTION=$(ugum choose "Enable" "Disable" "Exit without changes")
        case "$OPTION" in
            "Enable")
                enable_starship
                enable_zoxide
                enable_aliases
                ;;
            "Disable")
                disable_starship
                disable_zoxide
                disable_aliases
                ;;
            *)
                echo "No changes made."
                ;;
        esac
        exit 0
    fi
