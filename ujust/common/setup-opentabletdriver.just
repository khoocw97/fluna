# Manage OpenTabletDriver, an open source, cross-platform, user-mode tablet driver. Options: status | install | uninstall
opentabletdriver ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    get_status_token() {
        if flatpak list --columns=application 2>/dev/null | grep -Fx 'net.opentabletdriver.OpenTabletDriver' >/dev/null || \
           [[ -f "$HOME/.config/systemd/user/opentabletdriver.service" ]]; then
            echo "install"
        else
            echo "uninstall"
        fi
    }
    get_current_status() {
        if [[ "$(get_status_token)" == "install" ]]; then
            echo "Installed"
        else
            echo "Not Installed"
        fi
    }
    install_opentabletdriver() {
        echo "Installing OpenTabletDriver..."
        mkdir -p /tmp/OpenTabletDriver
        curl -fsSL https://api.github.com/repos/OpenTabletDriver/OpenTabletDriver/releases/latest \
        | grep -oP '"browser_download_url":\s*"\K[^"]+(?=")' \
        | grep -P 'opentabletdriver.*linux.*binary.*tar\.gz$' \
        | head -1 \
        | curl -fsSLo /tmp/OpenTabletDriver/opentabletdriver.tar.gz - && \
        tar --strip-components=1 -xzf /tmp/OpenTabletDriver/opentabletdriver.tar.gz -C /tmp/OpenTabletDriver && \
        sudo cp /tmp/OpenTabletDriver/etc/udev/rules.d/70-opentabletdriver.rules /etc/udev/rules.d/71-opentabletdriver.rules && \
        rm -rf /tmp/OpenTabletDriver && \
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && \
        flatpak --system install -y flathub net.opentabletdriver.OpenTabletDriver && \
        mkdir -p $HOME/.config/OpenTabletDriver && \
        flatpak override --user --filesystem=xdg-config/OpenTabletDriver net.opentabletdriver.OpenTabletDriver && \
        mkdir -p $HOME/.config/systemd/user && \
        curl -s https://raw.githubusercontent.com/flathub/net.opentabletdriver.OpenTabletDriver/refs/heads/master/scripts/opentabletdriver.service > $HOME/.config/systemd/user/opentabletdriver.service  && \
        systemctl --user daemon-reload && \
        systemctl enable --user --now opentabletdriver.service && \
        rpm-ostree kargs --append-if-missing=modprobe.blacklist=hid_uclogic --append-if-missing=modprobe.blacklist=wacom
    }
    uninstall_opentabletdriver() {
        echo "Uninstalling OpenTabletDriver..."
        sudo rm /etc/udev/rules.d/71-opentabletdriver.rules && \
        flatpak --system remove -y flathub net.opentabletdriver.OpenTabletDriver && \
        systemctl disable --user --now opentabletdriver.service && \
        rpm-ostree kargs --delete-if-present=modprobe.blacklist=hid_uclogic --delete-if-present=modprobe.blacklist=wacom
    }
    OPTION="{{ ACTION }}"
    if [[ "$OPTION" == "help" ]]; then
        echo "Usage: ujust opentabletdriver <option>"
        echo "  <option>: Specify the quick option to skip the prompt"
        echo "  Use 'status' to print the current portal token"
        echo "  Use 'install' to install OpenTabletDriver"
        echo "  Use 'uninstall' to uninstall OpenTabletDriver"
        exit 0
    elif [[ "$OPTION" == "status" ]]; then
        get_status_token
        exit $?
    elif [[ "$OPTION" == "install" ]]; then
        install_opentabletdriver
        exit 0
    elif [[ "$OPTION" == "uninstall" ]]; then
        uninstall_opentabletdriver
        exit 0
    elif [[ -z "$OPTION" ]]; then
        current_status=$(get_current_status)
        echo "${bold}OpenTabletDriver${normal}"
        echo "Current status: $current_status"
        OPTION=$(ugum choose "Install" "Uninstall" "Exit without changes")
        case "$OPTION" in
            "Install")
                install_opentabletdriver
                ;;
            "Uninstall")
                uninstall_opentabletdriver
                ;;
            *)
                echo "No changes made."
                ;;
        esac
        exit 0
    fi
