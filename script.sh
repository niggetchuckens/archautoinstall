#!/bin/bash

# Variables
DISK="/dev/nvme0n1" # Double check your drive with 'lsblk'
HOSTNAME="Yuki" # Your hostname for the install
USER="hime" # Your username
ROOT_PASSWORD="" # Root password
USER_PASSWORD="" # User password


echo "Formatting and Partitioning..."
parted -s $DISK mklabel gpt
parted -s $DISK mkpart ESP fat32 1MiB 513MiB
parted -s $DISK set 1 esp on
parted -s $DISK mkpart primary ext4 513MiB 750GiB

mkfs.vfat -F32 ${DISK}p1
mkfs.ext4 ${DISK}p2

mount ${DISK}p2 /mnt
mkdir /mnt/boot
mount ${DISK}p1 /mnt/boot

# Copy configuration files to be installed later
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
cp -r "$SCRIPT_DIR/oh-my-posh" /mnt/root/
cp "$SCRIPT_DIR/.bashrc" /mnt/root/

echo "Installing Base System..."
pacstrap /mnt base linux linux-firmware amd-ucode base-devel git networkmanager sudo

genfstab -U /mnt >> /mnt/etc/fstab

# Chroot configuration
arch-chroot /mnt <<EOF
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

# Root password
echo -e "$ROOT_PASSWORD\n$ROOT_PASSWORD" | passwd

# User setup
useradd -m -G wheel $USER
echo -e "$USER_PASSWORD\n$USER_PASSWORD" | passwd $USER
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=$HOSTNAME:OS
grub-mkconfig -o /boot/grub/grub.cfg

# Install Desktop Environment & Tools
pacman -S --noconfirm plasma-desktop sddm konsole dolphin wayland xorg-xwayland \
kitty vim nano gnome-screenshot pipewire openssh

# Enable Services
systemctl enable NetworkManager
systemctl enable sddm

EOF

# Install yay (outside chroot as the user)
arch-chroot /mnt <<EOF
cd /home/$USER
sudo -u $USER git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u $USER makepkg -si --noconfirm
cd ..
rm -rf yay

# Install personal apps
sudo -u $USER yay -S --noconfirm brave-bin visual-studio-code-bin spotify \
discord oh-my-posh nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils \
nvtop htop neofetch python python-pip python-virtualenv nodejs npm typescript \
android-studio docker docker-compose fpc texlive-core texlive-lang bash-completion \
cpupower-gui

# Enable Docker service
systemctl enable docker

# Enable ssh service
systemctl enable sshd

# Enable Nvidia drivers 
sudo envycontrol -s nvidia

# This is to regenerate the boot image just to be sure that nvidia modules are loaded at os boot
sudo mkinitcpio -P 

# Copy configuration files
mkdir -p /home/$USER/.config
cp -r /root/oh-my-posh /home/$USER/.config/
cp /root/.bashrc /home/$USER/.bashrc
chown -R $USER:$USER /home/$USER/.config/oh-my-posh
chown $USER:$USER /home/$USER/.bashrc
EOF

echo "Installation complete! Reboot now."