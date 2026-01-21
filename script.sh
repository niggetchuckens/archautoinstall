#!/bin/bash

read -rp "Insert the useranme to create a user:" USER

read -rsp "Enter the password for $USER: " PASSWORD
read -rsp "Confirm password: " PASSWDCHECK

if [[ "$PASSWORD" != "$PASSWDCHECK" ]]; then
  echo "Passwords don't match"
  exit 1
fi

echo "Available disks:"
lsblk -d -n -o NAME,SIZE,MODEL | grep -v "loop"

echo ""
read -rp "Enter the disk to begin with the instalation process: " DISK_NAME

# Variables
DISK="/dev/$DISK_NAME" # Double check your drive with 'lsblk'
HOSTNAME="Yuki"        # Your hostname for the install

echo "Select your CPU:"
echo "1) AMD"
echo "2) Intel"
read -rp "Choice: " CPU_CHOICE
if [[ "$CPU_CHOICE" == "1" ]]; then
  UCODE="amd-ucode"
else
  UCODE="intel-ucode"
fi

echo "Select your GPU:"
echo "1) AMD"
echo "2) Intel"
echo "3) Nvidia"
read -rp "Choice: " GPU_CHOICE
case $GPU_CHOICE in
  1) GPU_PACKAGES="mesa xf86-video-amdgpu vulkan-radeon";;
  2) GPU_PACKAGES="mesa xf86-video-intel vulkan-intel";;
  3) GPU_PACKAGES="nvidia-dkms nvidia-utils";;
  *) GPU_PACKAGES="";;
esac

read -rp "Do you want to download and install dotfiles? (y/n): " INSTALL_DOTFILES

# Formatting DISK

if [[ "$DISK" == *"nvme"* ]]; then
  PART1="${DISK}p1"
  PART2="${DISK}p2"
else
  PART1="${DISK}1"
  PART2="${DISK}2"
fi

echo "Formatting and Partitioning $DISK..."
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart "EFI" fat32 1MiB 513MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 513MiB 100%

mkfs.vfat -F 32 "$PART1"
mkfs.ext4 -F "$PART2"

mount "$PART2" /mnt
mount --mkdir "$PART1" /mnt/boot

mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys

echo "Installing Base System..."
pacstrap -K /mnt base linux linux-headers linux-firmware "$UCODE" base-devel git networkmanager sudo

genfstab -U /mnt >>/mnt/etc/fstab

# Chroot configuration
arch-chroot /mnt <<EOF
ln -sf /usr/share/zoneinfo/America/Santiago /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "$HOSTNAME" > /etc/hostname

# Root password
echo "Using same password as user previously defined"
echo -e "root:$PASSWORD" | chpasswd

# User setup
useradd -m -G wheel $USER
echo -e "$USER:$PASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=$HOSTNAME
grub-mkconfig -o /boot/grub/grub.cfg

# Install Minimal Tools & Drivers
pacman -S --noconfirm vim nano openssh python $GPU_PACKAGES

# Enable Services
systemctl enable NetworkManager
systemctl enable sshd

if [[ "$INSTALL_DOTFILES" == "y" || "$INSTALL_DOTFILES" == "Y" ]]; then
    echo "Installing yay..."
    su - $USER -c "cd ~ && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm"
    
    echo "Cloning and installing dotfiles..."
    su - $USER -c "cd ~ && git clone https://github.com/niggetchuckens/dotfiles.git && cd dotfiles && chmod +x install.sh && ./install.sh"
fi

EOF

echo "Installation complete! Reboot now."
