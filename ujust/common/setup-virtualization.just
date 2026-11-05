# Virtualization setup (libvirt/QEMU + USB hotplug). Options: virt-on | virt-off | help
setup-virtualization ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    if [[ $(id -u) -eq 0 ]]; then
      echo "Please do not run this command as root"
      exit 1
    fi
    # libvirt modular daemons are preset-enabled at image build, but re-check in case a big update reset them
    if [ "$(systemctl is-enabled virtqemud.socket 2>/dev/null)" != "enabled" ]; then
      echo "${b}libvirt${n} daemon sockets are ${red}disabled${n}!"
      echo "${green}enabling${n} and starting libvirt modular daemons"
      sudo systemctl enable --now virtqemud.service virtqemud.socket virtqemud-ro.socket virtqemud-admin.socket virtnetworkd.socket virtnetworkd-ro.socket virtnetworkd-admin.socket virtproxyd.socket virtproxyd-ro.socket virtproxyd-admin.socket
      echo "If virt-manager cannot connect after a big update, re-run this command."
    fi
    OPTION="{{ ACTION }}"
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust setup-virtualization <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'virt-on' to enable everything: virt-manager flatpak, KVM kernel args, SPICE USB hotplug, libvirt group"
      echo "  Use 'virt-off' to disable everything again"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}Virtualization Setup${normal}"
      echo "NOTE: Enabling will install the virt-manager flatpak, set KVM kernel args, enable SPICE USB hotplug and add $USER to the libvirt group"
      OPTION=$(ugum choose \
        "Enable Virtualization" \
        "Disable Virtualization" \
      )
    fi
    if [[ "${OPTION,,}" =~ (^enable[[:space:]]virtualization|virt-on) ]]; then
        if ! flatpak info --system org.virt_manager.virt-manager 1>/dev/null 2>&1; then
          echo "Installing virt-manager..."
          flatpak install --system --assumeyes flathub org.virt_manager.virt-manager
          echo "Making sure swtpm will work"
          if [ ! -d "/var/lib/swtpm-localca" ]; then
            sudo mkdir /var/lib/swtpm-localca
          fi
          sudo chown tss /var/lib/swtpm-localca
          echo "Giving qemu access to read ISO files from $HOME"
          sudo setfacl -m u:qemu:rx $HOME
        fi
        echo "Fixing libvirt SELinux log contexts"
        sudo restorecon -RFv /var/lib/libvirt
        sudo restorecon -RFv /var/log/libvirt
        sudo systemctl restart virtlogd
        echo "Setting KVM kernel args"
        rpm-ostree kargs \
        --append-if-missing="kvm.ignore_msrs=1" \
        --append-if-missing="kvm.report_ignored_msrs=0"
        echo "Adding SPICE USB hotplug udev rule"
        sudo bash -c 'cat << USBHP_UDEV > /etc/udev/rules.d/72-usbhp.rules
    ACTION=="add" SUBSYSTEM=="usb", TAG+="uaccess"
    USBHP_UDEV'
        echo "Adding $USER to libvirt group"
        sudo usermod -aG libvirt $USER
        echo 'Please reboot to apply changes'
    elif [[ "${OPTION,,}" =~ (^disable[[:space:]]virtualization|virt-off) ]]; then
      echo "Removing virt-manager..."
      if flatpak info --system org.virt_manager.virt-manager 1>/dev/null 2>&1; then
        flatpak uninstall --system --assumeyes org.virt_manager.virt-manager
      fi
      echo "Removing KVM kernel args"
      rpm-ostree kargs \
      --delete-if-present="kvm.ignore_msrs=1" \
      --delete-if-present="kvm.report_ignored_msrs=0"
      echo "Removing SPICE USB hotplug udev rule"
      sudo rm /etc/udev/rules.d/72-usbhp.rules
      echo 'Please reboot to apply changes'
    fi
