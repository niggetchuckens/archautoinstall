#!/bin/bash

# Variables
DISK="/dev/nvme0n1" # Double check your drive with 'lsblk'
HOSTNAME="Yuki" # Your hostname for the install
USER="hime" #your username

echo "Formatting and Partitioning..."
parted -s $DISK mklabel gpt
parted -s $DISK mkpart ESP fat32 1MiB 513MiB
parted -s $DISK set 1 esp on
parted -s $DISK mkpart primary ext4 513MiB 615GiB

mkfs.vfat -F32 ${DISK}p1
mkfs.ext4 ${DISK}p2

mount ${DISK}p2 /mnt
mkdir /mnt/boot
mount ${DISK}p1 /mnt/boot

# Copy configuration files to be installed later
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r "$SCRIPT_DIR/oh-my-posh" /mnt/root/
cp "$SCRIPT_DIR/.bashrc" /mnt/root/

echo "Installing Base System..."
pacstrap /mnt base linux linux-firmware amd-ucode nvidia nvidia-utils base-devel git networkmanager sudo

genfstab -U /mnt >> /mnt/etc/fstab

# Chroot configuration
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

# Root password
echo "root:root" | chpasswd

# User setup
useradd -m -G wheel $USER
echo "$USER:password" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Bootloader
bootctl install
echo -e "default arch\ntimeout 3" > /boot/loader/loader.conf
cat > /boot/loader/entries/arch.conf <<BOOTEOF
title Arch Linux
linux /vmlinuz-linux
initrd /amd-ucode.img
initrd /initramfs-linux.img
options root=${DISK}p2 rw nvidia-drm.modeset=1
BOOTEOF

# Enable Services
systemctl enable NetworkManager
systemctl enable sddm

# Install Desktop Environment & Tools
pacman -S --noconfirm plasma-desktop sddm konsole dolphin wayland xorg-xwayland \
kitty vim nano gnome-screenshot pipewire lib32-nvidia-utils

EOF

# Install yay (outside chroot as the user)
arch-chroot /mnt /bin/bash <<EOF
cd /home/$USER
sudo -u $USER git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u $USER makepkg -si --noconfirm
cd ..
rm -rf yay

# Install requested apps
sudo -u $USER yay -S --noconfirm brave-bin visual-studio-code-bin spotify discord oh-my-posh

# Copy configuration files
mkdir -p /home/$USER/.config
cp -r /root/oh-my-posh /home/$USER/.config/
cp /root/.bashrc /home/$USER/.bashrc
chown -R $USER:$USER /home/$USER/.config/oh-my-posh
chown $USER:$USER /home/$USER/.bashrc
EOF

echo "Installation complete! Reboot now."