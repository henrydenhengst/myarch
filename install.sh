#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
USER="henry"
PASS="henry12345"
DISK="/dev/sda"   # ⚠️ pas dit aan!
HOSTNAME=""
ROLE=""
UCODE=""
GPU_PKGS=""
BOOT_MODE=""
TARGET=""
CRYPT_PART=""
TIMEZONE="Europe/Amsterdam"
LOCALE="en_US.UTF-8"

echo "==> Detecting hardware..."

# --- CPU microcode
if grep -qi intel /proc/cpuinfo; then
  UCODE="intel-ucode"
elif grep -qi amd /proc/cpuinfo; then
  UCODE="amd-ucode"
fi

# --- GPU
if lspci | grep -qi nvidia; then
  GPU_PKGS="nvidia nvidia-utils nvidia-settings"
elif lspci | grep -qi amd; then
  GPU_PKGS="xf86-video-amdgpu"
elif lspci | grep -qi intel; then
  GPU_PKGS="mesa xf86-video-intel"
fi

# --- Laptop vs desktop
if dmidecode -s system-product-name 2>/dev/null | grep -qi laptop; then
  ROLE="laptop"
  HOSTNAME="laptop.netwerk.lan"
else
  ROLE="desktop"
  HOSTNAME="desktop.netwerk.lan"
fi

# --- Boot mode
if [ -d /sys/firmware/efi ]; then
  BOOT_MODE="uefi"
else
  BOOT_MODE="bios"
fi

echo "==> Wiping and partitioning disk $DISK..."
sgdisk --zap-all "$DISK"

if [ "$BOOT_MODE" = "uefi" ]; then
  parted -s "$DISK" mklabel gpt \
    mkpart ESP fat32 1MiB 512MiB set 1 boot on \
    mkpart cryptroot 512MiB 100%
  ESP_PART="${DISK}1"
  CRYPT_PART="${DISK}2"
else
  parted -s "$DISK" mklabel msdos \
    mkpart primary 1MiB 100% set 1 boot on
  CRYPT_PART="${DISK}1"
fi

echo "==> Setting up encryption..."
echo -n "$PASS" | cryptsetup luksFormat "$CRYPT_PART" -
echo -n "$PASS" | cryptsetup open "$CRYPT_PART" cryptroot -

# --- Filesystem
if lsblk -dno rota "$DISK" | grep -q 0; then
  echo "==> SSD/NVMe detected, using Btrfs..."
  mkfs.btrfs /dev/mapper/cryptroot
  mount /dev/mapper/cryptroot /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  umount /mnt
  mount -o subvol=@ /dev/mapper/cryptroot /mnt
  mkdir /mnt/home
  mount -o subvol=@home /dev/mapper/cryptroot /mnt/home
else
  echo "==> HDD detected, using ext4..."
  mkfs.ext4 /dev/mapper/cryptroot
  mount /dev/mapper/cryptroot /mnt
fi

if [ "$BOOT_MODE" = "uefi" ]; then
  mkfs.fat -F32 "$ESP_PART"
  mkdir /mnt/boot
  mount "$ESP_PART" /mnt/boot
fi

echo "==> Base install..."
pacstrap -K /mnt base linux linux-lts linux-firmware $UCODE $GPU_PKGS \
  networkmanager sudo vim nano reflector \
  cinnamon sddm xorg firefox \
  terminator kitty \
  ufw neofetch htop btop wget curl unzip zip p7zip \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
  bluez bluez-utils cups system-config-printer sane-airscan \
  ttf-dejavu ttf-liberation noto-fonts noto-fonts-emoji ttf-fira-code \
  zram-generator timeshift

if [ "$ROLE" = "laptop" ]; then
  pacstrap -K /mnt tlp powertop upower acpid brightnessctl
else
  pacstrap -K /mnt base-devel git \
    virt-manager qemu libvirt dnsmasq vde2 bridge-utils openbsd-netcat
fi

echo "==> Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# --- Post-install script inside chroot
cat > /mnt/root/postinstall.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

USER="henry"
PASS="henry12345"
HOSTNAME="$HOSTNAME"
ROLE="$ROLE"
BOOT_MODE="$BOOT_MODE"

echo "==> Setting timezone and locale..."
ln -sf /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "==> Setting hostname..."
echo "$HOSTNAME" > /etc/hostname

echo "==> Initramfs..."
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

echo "==> Setting root password lock and creating user..."
echo "root:!" | chpasswd -e
useradd -m -G wheel "$USER"
echo "$USER:$PASS" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/00_wheel

echo "==> Bootloader..."
if [ "$BOOT_MODE" = "uefi" ]; then
  bootctl --path=/boot install
  UUID=$(blkid -s UUID -o value $CRYPT_PART)
  cat > /boot/loader/entries/arch.conf <<EOL
title   Arch Linux
linux   /vmlinuz-linux
initrd  /$UCODE.img
initrd  /initramfs-linux.img
options cryptdevice=UUID=$UUID:cryptroot root=/dev/mapper/cryptroot rw
EOL
  cat > /boot/loader/entries/arch-lts.conf <<EOL
title   Arch Linux LTS
linux   /vmlinuz-linux-lts
initrd  /$UCODE.img
initrd  /initramfs-linux-lts.img
options cryptdevice=UUID=$UUID:cryptroot root=/dev/mapper/cryptroot rw
EOL
else
  pacman -S --noconfirm grub
  grub-install --target=i386-pc $DISK
  grub-mkconfig -o /boot/grub/grub.cfg
fi

echo "==> Enable services..."
systemctl enable NetworkManager
systemctl enable sddm
systemctl enable ufw
systemctl enable systemd-timesyncd
systemctl enable cups
systemctl enable bluetooth

if [ "$ROLE" = "laptop" ]; then
  systemctl enable tlp
  systemctl mask systemd-rfkill.service systemd-rfkill.socket || true
  systemctl enable acpid
else
  systemctl enable libvirtd
  systemctl enable virtlogd
fi

echo "==> Done! Reboot after exit."
EOF

chmod +x /mnt/root/postinstall.sh
arch-chroot /mnt /root/postinstall.sh
