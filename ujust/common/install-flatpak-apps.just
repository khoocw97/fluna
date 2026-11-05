# Install Flatpak apps from Flathub. Options: all | <app> | list | help
install-flatpak-apps APP="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh

    # Friendly name -> Flatpak app ID(s)
    APPS=(firefox chrome obs cine localsend protonvpn missioncenter flatseal warehouse gearlever pdfarranger rnote xournalpp onlyoffice)
    declare -A APP_IDS=(
        [firefox]="org.mozilla.firefox"
        [chrome]="com.google.Chrome"
        [obs]="com.obsproject.Studio com.obsproject.Studio.Plugin.Gstreamer com.obsproject.Studio.Plugin.GStreamerVaapi"
        [cine]="io.github.diegopvlk.Cine"
        [localsend]="org.localsend.localsend_app"
        [protonvpn]="com.protonvpn.www"
        [missioncenter]="io.missioncenter.MissionCenter"
        [flatseal]="com.github.tchx84.Flatseal"
        [warehouse]="io.github.flattool.Warehouse"
        [gearlever]="it.mijorus.gearlever"
        [pdfarranger]="com.github.jeromerobert.pdfarranger"
        [rnote]="com.github.flxzt.rnote"
        [xournalpp]="com.github.xournalpp.xournalpp"
        [onlyoffice]="org.onlyoffice.desktopeditors"
    )

    install_apps() {
        local app id
        # flatpak-preinstall.service already replaced fedora with Flathub for the
        # system installation; user installs need their own remote.
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        for app in "$@"; do
            for id in ${APP_IDS[$app]}; do
                echo "Installing $id..."
                flatpak install --user --assumeyes --noninteractive flathub "$id"
            done
        done
    }

    OPTION="{{ APP }}"
    case "$OPTION" in
        help)
            echo "Usage: ujust install-flatpak-apps <option>"
            echo "  <option>: Specify the quick option to skip the prompt"
            echo "  Use 'list' to print the available apps"
            echo "  Use 'all' to install every app"
            echo "  Available apps: ${APPS[*]}"
            exit 0
            ;;
        list)
            printf '%s\n' "${APPS[@]}"
            exit 0
            ;;
        all)
            install_apps "${APPS[@]}"
            exit 0
            ;;
        "")
            echo "${bold}Flatpak apps${normal}"
            OPTION=$(ugum choose "${APPS[@]}" "All apps" "Exit without changes")
            if [[ "$OPTION" == "All apps" ]]; then
                install_apps "${APPS[@]}"
            elif [[ -n "$OPTION" && "$OPTION" != "Exit without changes" ]]; then
                install_apps "$OPTION"
            else
                echo "No changes made."
            fi
            exit 0
            ;;
    esac

    if [[ -n "${APP_IDS[$OPTION]:-}" ]]; then
        install_apps "$OPTION"
    else
        echo "Unknown app: $OPTION"
        echo "Run 'ujust install-flatpak-apps help' for the list."
        exit 1
    fi
