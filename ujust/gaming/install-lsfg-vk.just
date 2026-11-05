# Manage LSFG-VK frame generation (Lossless Scaling frame generation, requires the Steam version of Lossless Scaling). Options: status | install | uninstall
lsfg-vk ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    get_status_token() {
        if [[ -f "$HOME/.local/lib/liblsfg-vk-layer.so" ]] && \
           [[ -f "$HOME/.local/share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.json" ]]; then
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
    remove_lsfg_files() {
        rm -f \
            "$HOME/.local/bin/lsfg-vk-cli" \
            "$HOME/.local/bin/lsfg-vk-ui" \
            "$HOME/.local/lib/liblsfg-vk-layer.x86.so" \
            "$HOME/.local/lib/liblsfg-vk-layer.so" \
            "$HOME/.local/share/applications/gay.pancake.lsfg-vk-ui.desktop" \
            "$HOME/.local/share/icons/hicolor/256x256/apps/gay.pancake.lsfg-vk-ui.png" \
            "$HOME/.local/share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.x86.json" \
            "$HOME/.local/share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.json"
    }
    install_lsfg() {
        echo "Installing LSFG-VK..."
        echo "Finding the latest release..."
        BUILDS_URL="https://builds.lsfg-vk.dev/"
        RELEASE_PATH=$(
            timeout 30 curl -fsSL "$BUILDS_URL" |
                grep 'Latest release (' |
                sed -n 's/.*href="\([^"]*\.tar\.xz\)".*/\1/p' |
                head -n 1
        )
        if [ -z "$RELEASE_PATH" ]; then
            echo "Failed to find the latest release, please check your network and try again"
            exit 1
        fi
        if [[ "$RELEASE_PATH" =~ ^https?:// ]]; then
            DOWNLOAD_URL="$RELEASE_PATH"
        else
            DOWNLOAD_URL="${BUILDS_URL}${RELEASE_PATH#./}"
        fi
        TEMP_DIR=$(mktemp -d)
        if [ -z "$TEMP_DIR" ] || [ ! -d "$TEMP_DIR" ]; then
            echo "Failed to create temporary directory"
            exit 1
        fi
        trap 'rm -rf "$TEMP_DIR"' EXIT
        ARCHIVE="$TEMP_DIR/lsfg-vk.tar.xz"
        if ! timeout 60 curl -fL "$DOWNLOAD_URL" -o "$ARCHIVE"; then
            echo "Download failed or timed out, please check your network and try again"
            exit 1
        fi
        if ! tar -tf "$ARCHIVE" | grep -q 'lib/liblsfg-vk-layer.so' || \
           ! tar -tf "$ARCHIVE" | grep -q 'share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.json'; then
            echo "Downloaded archive is not a valid LSFG-VK package"
            exit 1
        fi
        remove_lsfg_files
        echo "Installing to ~/.local ..."
        mkdir -p "$HOME/.local"
        if ! tar -xf "$ARCHIVE" -C "$HOME/.local"; then
            echo "Installation failed"
            exit 1
        fi
        if [[ ! -f "$HOME/.local/lib/liblsfg-vk-layer.so" ]] || \
           [[ ! -f "$HOME/.local/share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.json" ]]; then
            echo "Installation failed: expected files were not found"
            exit 1
        fi
        rm -rf "$TEMP_DIR"
        trap - EXIT
        echo "Installed successfully! LSFG-VK UI is now available in your applications menu"
        echo "Please ensure Lossless Scaling is installed through Steam"
    }
    uninstall_lsfg() {
        echo "Uninstalling LSFG-VK..."
        remove_lsfg_files
        echo "Uninstalled successfully!"
    }
    OPTION="{{ ACTION }}"
    if [[ "$OPTION" == "help" ]]; then
        echo "Usage: ujust lsfg-vk <option>"
        echo "  <option>: Specify the quick option to skip the prompt"
        echo "  Use 'status' to print the current status token"
        echo "  Use 'install' to install LSFG-VK"
        echo "  Use 'uninstall' to uninstall LSFG-VK"
        exit 0
    elif [[ "$OPTION" == "status" ]]; then
        get_status_token
        exit $?
    elif [[ "$OPTION" == "install" ]]; then
        install_lsfg
        exit 0
    elif [[ "$OPTION" == "uninstall" ]]; then
        uninstall_lsfg
        exit 0
    elif [[ -z "$OPTION" ]]; then
        current_status=$(get_current_status)
        echo "${bold}LSFG-VK Frame Generation${normal}"
        echo "Current status: $current_status"
        OPTION=$(ugum choose "Install" "Uninstall" "Exit without changes")
        case "$OPTION" in
            "Install")
                install_lsfg
                ;;
            "Uninstall")
                uninstall_lsfg
                ;;
            *)
                echo "No changes made."
                ;;
        esac
        exit 0
    fi
