#!/bin/bash
set -euo pipefail
clear

# ==========================
# Arch Linux Turnkey Installer
# ==========================

echo "==================================="
echo "   WELKOM BIJ DE ARCH INSTALLER    "
echo "==================================="

# --------------------------
# Detecteer hardware
# --------------------------
echo "[+] Detecteer hardware..."
CPU_VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}')
GPU_VENDOR=$(lspci | grep -i "vga" | head -n1 | awk -F ': ' '{print $2}')
if dmidecode -s system-product-name 2>/dev/null | grep -qi laptop; then
    SYSTEM_TYPE="laptop"
else
    SYSTEM_TYPE="desktop"
fi
echo "    CPU: $CPU_VENDOR, GPU: $GPU_VENDOR, Type: $SYSTEM_TYPE"

# --------------------------
# Doelschijf prompt
# --------------------------
DEFAULT_DISK=$(lsblk -dpno NAME,ROTA,SIZE,MODEL | grep -v "USB" | grep -v "loop" | head -n1 | awk '{print $1}')
read -rp "Doelschijf [$DEFAULT_DISK]: " DISK
DISK=${DISK:-$DEFAULT_DISK}
echo "[+] Gebruik: $DISK"

# --------------------------
# Gebruiker prompt
# --------------------------
DEFAULT_USER="gebruiker"
read -rp "Gebruikersnaam [$DEFAULT_USER]: " USER
USER=${USER:-$DEFAULT_USER}

DEFAULT_PASS="henry12345"
read -rsp "Wachtwoord [$DEFAULT_PASS]: " PASS
echo
PASS=${PASS:-$DEFAULT_PASS}

# --------------------------
# Hostname prompt
# --------------------------
if [[ "$SYSTEM_TYPE" == "laptop" ]]; then
    DEFAULT_HOSTNAME="laptop.netwerk.lan"
else
    DEFAULT_HOSTNAME="desktop.netwerk.lan"
fi
read -rp "Hostname [$DEFAULT_HOSTNAME]: " HOSTNAME
HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}
echo "[+] Hostname: $HOSTNAME"

# --------------------------
# Tijdzone & locale
# --------------------------
ln -sf /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo $HOSTNAME > /etc/hostname

# --------------------------
# Partitionering & encryptie
# --------------------------
echo "[+] Partitioneer en encrypt de schijf..."
sgdisk -Z $DISK
sgdisk -n1:0:+512M -t1:ef00 -c1:"EFI" $DISK
sgdisk -n2:0:0 -t2:8300 -c2:"Linux" $DISK

EFI_PART="${DISK}1"
ROOT_PART="${DISK}2"

# Encrypt root
echo -n "$PASS" | cryptsetup luksFormat $ROOT_PART -
echo -n "$PASS" | cryptsetup open $ROOT_PART cryptroot -

mkfs.fat -F32 $EFI_PART
mkfs.btrfs /dev/mapper/cryptroot -f

mount /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot
mount $EFI_PART /mnt/boot

# --------------------------
# Base installatie
# --------------------------
echo "[+] Installeer base system..."
pacstrap /mnt base linux linux-firmware vim sudo bash-completion networkmanager

# --------------------------
# Fstab
# --------------------------
genfstab -U /mnt >> /mnt/etc/fstab

# --------------------------
# Chroot setup
# --------------------------
arch-chroot /mnt /bin/bash <<EOF
set -e

# --------------------------
# Time & locale inside chroot
# --------------------------
ln -sf /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime
hwclock --systohc
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

# --------------------------
# Users
# --------------------------
useradd -m -G wheel -s /bin/bash $USER
echo "$USER:$PASS" | chpasswd
echo "root:$PASS" | chpasswd
passwd -l root

# --------------------------
# Sudo
# --------------------------
pacman -S --noconfirm sudo
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# --------------------------
# Bootloader
# --------------------------
bootctl --path=/boot install
cat <<EOL > /boot/loader/loader.conf
default arch
timeout 3
EOL

ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)
cat <<EOL > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options cryptdevice=UUID=$ROOT_UUID:cryptroot root=/dev/mapper/cryptroot rw
EOL

# --------------------------
# Desktop environment
# --------------------------
pacman -S --noconfirm cinnamon sddm xorg xorg-xinit
systemctl enable sddm
systemctl enable NetworkManager

# --------------------------
# Hardware drivers
# --------------------------
if [[ "$GPU_VENDOR" == *NVIDIA* ]]; then
    pacman -S --noconfirm nvidia nvidia-utils nvidia-settings
elif [[ "$GPU_VENDOR" == *AMD* ]]; then
    pacman -S --noconfirm xf86-video-amdgpu
elif [[ "$GPU_VENDOR" == *Intel* ]]; then
    pacman -S --noconfirm mesa xf86-video-intel
fi

# --------------------------
# Laptop specific services
# --------------------------
if [[ "$SYSTEM_TYPE" == "laptop" ]]; then
    pacman -S --noconfirm tlp acpi acpid powertop upower
    systemctl enable tlp
    systemctl enable acpid
fi

# --------------------------
# Desktop specific services
# --------------------------
if [[ "$SYSTEM_TYPE" == "desktop" ]]; then
    pacman -S --noconfirm qemu libvirt virt-manager dnsmasq bridge-utils
    systemctl enable libvirtd
fi

# --------------------------
# Extra apps
# --------------------------
pacman -S --noconfirm firefox terminator kitty neofetch btop timeshift pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber bluez bluez-utils cups

# --------------------------
# Firewall
# --------------------------
pacman -S --noconfirm ufw
systemctl enable ufw
ufw enable

EOF

# --------------------------
# Unmount & reboot
# --------------------------
umount -R /mnt
cryptsetup close cryptroot

echo "[+] Installatie voltooid! Herstart nu je computer."
