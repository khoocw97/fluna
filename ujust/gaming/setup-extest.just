# Add the current user to the input group, required by extest to create uinput devices. Options: status | enable | disable
setup-extest ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    get_status_token() {
        if id -nG "$USER" | grep -qw input; then
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
    enable_extest() {
        echo "Adding $USER to the input group..."
        sudo usermod -aG input "$USER" && \
        echo "Added. Log out and back in for it to take effect."
    }
    disable_extest() {
        echo "Removing $USER from the input group..."
        sudo gpasswd -d "$USER" input && \
        echo "Removed. Log out and back in for it to take effect."
    }
    OPTION="{{ ACTION }}"
    if [[ "$OPTION" == "help" ]]; then
        echo "Usage: ujust setup-extest <option>"
        echo "  <option>: Specify the quick option to skip the prompt"
        echo "  Use 'status' to print the current status token"
        echo "  Use 'enable' to add the current user to the input group"
        echo "  Use 'disable' to remove the current user from the input group"
        exit 0
    elif [[ "$OPTION" == "status" ]]; then
        get_status_token
        exit $?
    elif [[ "$OPTION" == "enable" ]]; then
        enable_extest
        exit 0
    elif [[ "$OPTION" == "disable" ]]; then
        disable_extest
        exit 0
    elif [[ -z "$OPTION" ]]; then
        echo "${bold}Extest Input Group${normal}"
        echo "Current status: $(get_current_status)"
        OPTION=$(ugum choose "Enable" "Disable" "Exit without changes")
        case "$OPTION" in
            "Enable")
                enable_extest
                ;;
            "Disable")
                disable_extest
                ;;
            *)
                echo "No changes made."
                ;;
        esac
        exit 0
    fi
