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
mkfs.ext4 -F "$PART1"

mount "$PART2" /mnt
mount --mkdir "$PART1" /mnt/boot

mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys

# Copy configuration files to be installed later
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r "$SCRIPT_DIR/oh-my-posh" /mnt/root/
cp "$SCRIPT_DIR/.bashrc" /mnt/root/

echo "Installing Base System..."
pacstrap -K /mnt base linux linux-firmware amd-ucode base-devel git networkmanager sudo

genfstab -U /mnt >>/mnt/etc/fstab

# Chroot configuration
arch-chroot /mnt <<EOF
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
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
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=$HOSTNAME
grub-mkconfig -o /boot/grub/grub.cfg

# Install Desktop Environment & Tools
pacman -S --noconfirm gdm dolphin wayland xorg-xwayland \
kitty vim nano openssh 

# Enable Services
systemctl enable NetworkManager
systemctl enable sddm

su - $USER

cd /home/$USER
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
rm -rf yay

# Install personal apps
yay -S --noconfirm brave-bin visual-studio-code-bin spotify \
discord oh-my-posh nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils \
nvtop htop neofetch python python-pip python-virtualenv nodejs npm typescript \
android-studio docker docker-compose fpc texlive-core texlive-lang bash-completion \
cpupower-gui flameshot pipewire pipewire-pulse pipewire-alsa pipewire-jack \
wireplumber playerctl-git pavucontrol pulseaudio-ctl rofi wezterm hilbish \
x11-emoji-picker-git awesome-git uthash glib2-devel ninja meson cmake

git clone https://github.com/jonaburg/picom
cd picom
meson setup --buildtype=release build
ninja -C build
sudo ninja -C build install

git clone --recurse-submodules https://github.com/ChocolateBread799/dotfiles
cd dotfiles
mv config/* ~/.config/

# Enable pipewire for audio 
systemctl --user enable --now pipewire.socket pipewire-pulse.socket \
pipewire,service pipewire-pulse.service wireplumber.service

# Enable Docker service
systemctl enable docker

# Enable ssh service
sudo systemctl enable sshd

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
