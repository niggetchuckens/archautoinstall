#!/bin/bash

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo (e.g., sudo bash fix-monitor.sh)"
  exit
fi

echo "--- Starting Nvidia Multi-Monitor Fix ---"

# 1. Back up and modify GRUB to enable DRM modesetting
if grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
    echo "[!] nvidia-drm.modeset=1 is already in GRUB. Skipping..."
else
    echo "[+] Adding nvidia-drm.modeset=1 to GRUB configuration..."
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 /' /etc/default/grub
    echo "[+] Updating GRUB..."
    grub-mkconfig -o /boot/grub/grub.cfg
fi

# 2. Handle potentially conflicting Xorg configs
if [ -f /etc/X11/xorg.conf ]; then
    echo "[+] Found old xorg.conf. Renaming to xorg.conf.bak to allow auto-detection..."
    mv /etc/X11/xorg.conf /etc/X11/xorg.conf.bak
fi

# 3. Ensure Mkinitcpio includes the nvidia modules
# This helps the driver load earlier in the boot process
if ! grep -q "nvidia nvidia_modeset nvidia_uvm nvidia_drm" /etc/mkinitcpio.conf; then
    echo "[+] Adding Nvidia modules to mkinitcpio..."
    # This is a basic injection; if your MODULES=() line is complex, check this manually
    sed -i 's/MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
    echo "[+] Regenerating initramfs..."
    mkinitcpio -P
fi

echo "--- Process Complete ---"
echo "Please reboot your computer now to see if the second monitor works."