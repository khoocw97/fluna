# Auto-mount external drives with udiskie.
automount ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    get_status_token() {
        if systemctl --user is-enabled --quiet udiskie.service 2>/dev/null; then
            echo "enable"
        else
            echo "disable"
        fi
    }
    get_current_status() {
        if [[ "$(get_status_token)" == "enable" ]]; then
            echo "Enabled"
        else
            echo "Disabled"
        fi
    }
    enable_automount() {
        echo "Enabling automounting..."
        systemctl --user enable --now udiskie.service && \
        echo "Automounting enabled"
    }
    disable_automount() {
        echo "Disabling automounting..."
        systemctl --user disable --now udiskie.service && \
        echo "Automounting disabled"
    }
    OPTION="{{ ACTION }}"
    if [[ "$OPTION" == "help" ]]; then
        echo "Usage: ujust automount <option>"
        echo "  <option>: Specify the quick option to skip the prompt"
        echo "  Use 'status' to print the current status token"
        echo "  Use 'enable' to auto-mount external drives"
        echo "  Use 'disable' to stop automounting"
        exit 0
    elif [[ "$OPTION" == "status" ]]; then
        get_status_token
        exit $?
    elif [[ "$OPTION" == "enable" ]]; then
        enable_automount
        exit 0
    elif [[ "$OPTION" == "disable" ]]; then
        disable_automount
        exit 0
    elif [[ -z "$OPTION" ]]; then
        echo "${bold}Current status:${normal} $(get_current_status)"
        OPTION=$(ugum choose "Enable" "Disable" "Exit without changes")
        case "$OPTION" in
            "Enable")
                enable_automount
                ;;
            "Disable")
                disable_automount
                ;;
            *)
                echo "No changes made."
                ;;
        esac
        exit 0
    fi
