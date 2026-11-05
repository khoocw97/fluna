# Fix Steam / Proton issues. Options: status | proton | steam | all
fix-steam-proton ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    fix_proton_hang() {
        echo "Killing hung Proton processes..."
        killall -9 pv-bwrap pressure-vessel reaper explorer.exe rpcss.exe plugplay.exe services.exe svchost.exe winedevice.exe wineserver 2>/dev/null || true
        echo "Proton processes killed."
    }
    fix_reset_steam() {
        STEAMPATH="$HOME/.local/share/Steam"
        STEAMFILES=$(ls "$HOME/.local/share/Steam/" | grep -vP "(userdata|compatibilitytools\.d|config|controller_base|steamapps|music)")
        echo "This script will ${b}remove${n} a bunch of files from $STEAMPATH and sign you out of steam!"
        echo "However your games, music, saves, controller profiles and compatibilitytools/custom-proton will not be touched."
        echo "To cancel and abort this operation press CTRL+C now, to continue press ENTER."
        read -r i
        systemctl --user stop steam-wrapper.service 2>/dev/null || true
        killall -9 steam-wrapper 2>/dev/null || true
        killall -9 steam 2>/dev/null || true
        sleep 1
        echo "Resetting Steam to a freshly installed state."
        for STEAMFILE in $STEAMFILES; do
            if [ -d "$STEAMPATH/$STEAMFILE" ]; then
                rm -rv "$STEAMPATH/$STEAMFILE"
            elif [ -f "$STEAMPATH/$STEAMFILE" ]; then
                rm -v "$STEAMPATH/$STEAMFILE"
            fi
        done
        sleep 1
    }
    OPTION="{{ ACTION }}"
    if [[ "$OPTION" == "help" ]]; then
        echo "Usage: ujust fix-steam-proton <option>"
        echo "  <option>: Specify the quick option to skip the prompt"
        echo "  Use 'proton' to kill hung Proton processes"
        echo "  Use 'steam' to reset Steam to a freshly installed state"
        echo "  Use 'all' to run both"
        exit 0
    elif [[ "$OPTION" == "proton" ]]; then
        fix_proton_hang
        exit 0
    elif [[ "$OPTION" == "steam" ]]; then
        fix_reset_steam
        exit 0
    elif [[ "$OPTION" == "all" ]]; then
        fix_proton_hang
        fix_reset_steam
        exit 0
    elif [[ -z "$OPTION" ]]; then
        echo "${bold}Fix Steam/Proton${normal}"
        OPTION=$(ugum choose "Kill Proton hang" "Reset Steam" "Both" "Exit without changes")
        case "$OPTION" in
            "Kill Proton hang")
                fix_proton_hang
                ;;
            "Reset Steam")
                fix_reset_steam
                ;;
            "Both")
                fix_proton_hang
                fix_reset_steam
                ;;
            *)
                echo "No changes made."
                ;;
        esac
        exit 0
    fi