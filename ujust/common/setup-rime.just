# 管理 Rime 配置（安装全拼/双拼、更新）。选项: install | install-shuangpin | update | status | help
setup-rime ACTION="":
    #!/usr/bin/env bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh

    RIME_DIR="$HOME/.local/share/fcitx5/rime"

    get_status_token() {
        if [ -d "$RIME_DIR" ] && [ -f "$RIME_DIR/default.yaml" ]; then
            echo "installed"
        else
            echo "not-installed"
        fi
    }

    get_current_status() {
        if [[ "$(get_status_token)" == "installed" ]]; then
            echo "已安装"
        else
            echo "未安装"
        fi
    }

    clone_plum() {
        TMP_DIR=$(mktemp -d)
        if ! git clone https://github.com/rime/plum.git "$TMP_DIR/plum"; then
            rm -rf "$TMP_DIR"
            echo "Git 拉取失败，请检查网络后重试，未更改现有配置"
            return 1
        fi
    }

    install_rime() {
        echo "安装 Rime 配置（全拼，从本地内置数据）..."
        mkdir -p "$RIME_DIR"
        cp -r /usr/share/rime-ice/* "$RIME_DIR"
        echo "已安装本地内置数据"
        restart_fcitx5
    }

    install_shuangpin() {
        scheme_labels=(自然码 小鹤 微软 搜狗 智能ABC 拼音加加 紫光 取消)
        scheme_values=(double_pinyin double_pinyin_flypy double_pinyin_mspy double_pinyin_sogou double_pinyin_abc double_pinyin_jiajia double_pinyin_ziguang cancel)
        echo "选择双拼方案..."
        sel=$(ugum choose "${scheme_labels[@]}") || sel=""
        if [[ "$sel" == "取消" ]]; then
            echo "已取消"
            return 0
        fi
        scheme=""
        for i in "${!scheme_labels[@]}"; do
            if [[ "${scheme_labels[$i]}" == "$sel" ]]; then
                scheme="${scheme_values[$i]}"
                break
            fi
        done
        if [[ -z "$scheme" ]]; then
            echo "已取消"
            return 0
        fi
        echo "安装双拼方案 $sel ($scheme) ..."
        clone_plum || return 1
        cd "$TMP_DIR/plum"
        rime_dir="$RIME_DIR" bash rime-install iDvel/rime-ice
        rime_dir="$RIME_DIR" bash rime-install "iDvel/rime-ice:others/recipes/config:schema=$scheme"
        rime_dir="$RIME_DIR" bash rime-install "iDvel/rime-ice:others/recipes/grammar:schema=$scheme"
        rime_dir="$RIME_DIR" bash rime-install "iDvel/rime-ice:others/recipes/reverse_tone:schema=$scheme"
        rm -rf "$TMP_DIR"
        echo "已安装 $sel 双拼方案"
        restart_fcitx5
    }

    update_rime() {
        echo "更新 Rime 配置（从 Git 拉取最新）..."
        clone_plum || return 1
        cd "$TMP_DIR/plum"
        rime_dir="$RIME_DIR" bash rime-install iDvel/rime-ice
        rm -rf "$TMP_DIR"
        echo "已更新到最新版本"
        restart_fcitx5
    }

    restart_fcitx5() {
        if pgrep -x fcitx5 > /dev/null; then
            busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 SetConfig sv "fcitx://config/addon/rime/deploy" s "" > /dev/null 2>&1
            echo "Rime 重新部署中，请等待 5 秒..."
            sleep 5
            echo "Rime 已重新部署"
        else
            echo "fcitx5-rime 部署失败，请重启fcitx5"
        fi
    }

    OPTION="{{ ACTION }}"
    if [[ "$OPTION" == "help" ]]; then
        echo "Usage: ujust setup-rime <option>"
        echo "  <option>: Specify the quick option to skip the prompt"
        echo "  Use 'status' to print current status token"
        echo "  Use 'install' to install built-in full pinyin data"
        echo "  Use 'install-shuangpin' to install a double pinyin scheme via git"
        echo "  Use 'update'  to update from Git repository"
        exit 0
    elif [[ "$OPTION" == "status" ]]; then
        get_status_token
        exit $?
    elif [[ "$OPTION" == "install" ]]; then
        install_rime
        exit 0
    elif [[ "$OPTION" == "install-shuangpin" ]]; then
        install_shuangpin
        exit 0
    elif [[ "$OPTION" == "update" ]]; then
        update_rime
        exit 0
    elif [[ -z "$OPTION" ]]; then
        current_status=$(get_current_status)
        echo "${bold}Rime 配置${normal}"
        echo "当前状态: $current_status"
        choice=$(ugum choose "安装" "安装双拼" "更新" "退出不更改") || choice=""
        case "$choice" in
            "安装")
                install_rime
                ;;
            "安装双拼")
                install_shuangpin
                ;;
            "更新")
                update_rime
                ;;
            *)
                echo "没有更改。"
                ;;
        esac
        exit 0
    fi
